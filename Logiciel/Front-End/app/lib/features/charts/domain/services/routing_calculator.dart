import 'dart:math' as math;
import 'package:kornog/common/utils/angle_utils.dart';

import '../../domain/models/course.dart';
import 'wind_trend_analyzer.dart';

/// Type de segment parcouru par le routage.
enum RouteLegType { start, leg, finish }

class RouteLeg {
  RouteLeg({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.type,
    this.label,
    this.estimatedTime,
  });
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final RouteLegType type;
  final String? label; // ex: "B2->B3"
  final double? estimatedTime; // Temps estimé en secondes pour ce segment
}

class RoutePlan {
  RoutePlan(this.legs);
  final List<RouteLeg> legs;
  bool get isEmpty => legs.isEmpty;
  
  /// Temps total estimé en secondes pour le parcours complet
  double get totalEstimatedTime {
    return legs.fold(0.0, (sum, leg) => sum + (leg.estimatedTime ?? 0.0));
  }
  
  /// Temps total formaté en minutes et secondes
  String get formattedTotalTime {
    final totalSeconds = totalEstimatedTime;
    if (totalSeconds == 0.0) return "--:--";
    
    final minutes = (totalSeconds / 60).floor();
    final seconds = (totalSeconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Interface pour accéder aux données de polaire
abstract class PolarData {
  double getSpeedForConditions(double windSpeed, double twa);
}

/// Calculateur de routage très simple (MVP) :
/// - Point de départ = milieu de la ligne de départ si disponible sinon première bouée.
/// - Ordre des bouées = tri par passageOrder (croissant) puis par id croissant pour celles sans passageOrder.
/// - Ajoute éventuellement la bouée "target" (viseur) à la fin si elle existe et n'est pas déjà dans la séquence.
/// - Point final = milieu de la ligne d'arrivée si présent.
/// Ne calcule pas encore des laylines / VMG optimisés : cette partie viendra ensuite.
class RoutingCalculator {
  double? windDirDeg; // FROM direction en degrés (injecté optionnellement)
  double? windSpeed; // vitesse du vent en nœuds
  double? optimalUpwindAngle; // angle TWA optimum (ex: 40°)
  double? currentTwaSigned; // TWA signé courant (-180..180) provenant télémétrie
  PolarData? polarData; // données de polaire pour calculs de vitesse

  RoutingCalculator({
    this.windDirDeg, 
    this.windSpeed,
    this.optimalUpwindAngle, 
    this.currentTwaSigned,
    this.polarData,
  });

  RoutePlan compute(CourseState course, {WindTrendSnapshot? windTrend}) {
    print('COMPUTE ROUTING - Début du calcul de route');
    final legs = <RouteLeg>[];

    // Récupération bouées (exclure comité/target pour séquence principale, target gérée après)
    final regular = course.buoys.where((b) => b.role == BuoyRole.regular).toList();
    // Tri par passageOrder défini puis par id
    regular.sort((a, b) {
      final ao = a.passageOrder;
      final bo = b.passageOrder;
      if (ao != null && bo != null) {
        final c = ao.compareTo(bo);
        if (c != 0) return c;
      } else if (ao != null) {
        return -1; // a avant b
      } else if (bo != null) {
        return 1;
      }
      return a.id.compareTo(b.id);
    });

    // Bouée target (viseur)
    final target = course.buoys.where((b) => b.role == BuoyRole.target).cast<Buoy?>().firstWhere(
          (b) => true,
          orElse: () => null,
        );

    // Point de départ : côté optimal de la ligne de départ sinon première bouée
    double? curX;
    double? curY;
    if (course.startLine != null) {
      final optimalStart = _getOptimalStartPoint(course.startLine!, regular, windTrend);
      curX = optimalStart.x;
      curY = optimalStart.y;
    } else if (regular.isNotEmpty) {
      curX = regular.first.x;
      curY = regular.first.y;
    }

    // Ajoute segment début -> première bouée seulement si départ existe et qu'on a des bouées
    if (course.startLine != null && regular.isNotEmpty) {
      final first = regular.first;
      final startMidX = curX!; // non null ici
      final startMidY = curY!;
        // Fallback route directe - UTILISER le système de routing avec tacks
      // Route directe avec système de routing tactique
      print('ROUTING DEBUG - Creating Start->B1 segment: ($startMidX,$startMidY) -> (${first.x},${first.y})');
      final seg = _routeLegWithTacksIfNeeded(startMidX, startMidY, first.x, first.y, label: 'Start->B${first.id}', windTrend: windTrend);
      print('ROUTING DEBUG - Start->B1 segments created: ${seg.length}');
      legs.addAll(seg);
      curX = first.x;
      curY = first.y;
    }

    // Parcours bouées régulières restantes
    for (var i = 0; i < regular.length; i++) {
      final b = regular[i];
      if (curX == null || curY == null) {
        curX = b.x;
        curY = b.y;
        continue; // pas de segment initial
      }
      if (curX == b.x && curY == b.y) continue; // déjà positionné
      final seg = _routeLegWithTacksIfNeeded(curX, curY, b.x, b.y, label: 'B->B${b.id}', windTrend: windTrend);
      legs.addAll(seg);
      curX = b.x;
      curY = b.y;
    }

    // Le viseur (target) ne fait pas partie de la séquence de course
    // Il sert uniquement pour la ligne de départ
    // Nous ne l'ajoutons donc pas dans le routage

    // Arrivée : côté optimal de la ligne d'arrivée
    if (course.finishLine != null && curX != null && curY != null) {
      final optimalFinish = _getOptimalFinishPoint(course.finishLine!, curX, curY);
      final fx = optimalFinish.x;
      final fy = optimalFinish.y;
      if (fx != curX || fy != curY) {
        final seg = _routeLegWithTacksIfNeeded(curX, curY, fx, fy, label: 'Finish', finish: true, windTrend: windTrend);
        legs.addAll(seg);
      }
    }

    return RoutePlan(legs);
  }

  /// Distance totale approximative (euclidienne) - utilitaire.
  double totalDistance(RoutePlan plan) {
    double d = 0;
    for (final l in plan.legs) {
      d += math.sqrt(math.pow(l.endX - l.startX, 2) + math.pow(l.endY - l.startY, 2));
    }
    return d;
  }

  /// Détermine le point optimal de la ligne de départ
  /// Choisit P1 ou P2 selon la proximité avec la première bouée et les conditions tactiques
  math.Point<double> _getOptimalStartPoint(LineSegment startLine, List<Buoy> regular, WindTrendSnapshot? windTrend) {
    final p1 = math.Point(startLine.p1x, startLine.p1y);
    final p2 = math.Point(startLine.p2x, startLine.p2y);
    
    if (regular.isEmpty) {
      // Pas de bouée, prendre le milieu par défaut
      return math.Point((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);
    }
    
    final firstBuoy = regular.first;
    final targetPoint = math.Point(firstBuoy.x, firstBuoy.y);
    
    // Calcul des temps de parcours réels depuis chaque extrémité
    final timeFromP1 = _estimateTimeToTarget(p1.x, p1.y, targetPoint.x, targetPoint.y);
    final timeFromP2 = _estimateTimeToTarget(p2.x, p2.y, targetPoint.x, targetPoint.y);
    
    // Choix du point avec le temps de parcours le plus court
    final optimalPoint = timeFromP1 <= timeFromP2 ? p1 : p2;
    final chosenSide = timeFromP1 <= timeFromP2 ? "P1" : "P2";
    
    print('OPTIMAL_START - P1: (${p1.x.toStringAsFixed(1)}, ${p1.y.toStringAsFixed(1)}) temps=${timeFromP1.toStringAsFixed(1)}s');
    print('OPTIMAL_START - P2: (${p2.x.toStringAsFixed(1)}, ${p2.y.toStringAsFixed(1)}) temps=${timeFromP2.toStringAsFixed(1)}s');
    print('OPTIMAL_START - Choix: $chosenSide (temps optimal vers B${firstBuoy.id})');
    
    // Vérifier l'écart de temps
    final timeDiff = (timeFromP1 - timeFromP2).abs();
    if (timeDiff < 5.0) { // Si moins de 5 secondes d'écart
      print('OPTIMAL_START - Écart faible (${timeDiff.toStringAsFixed(1)}s), choix peu critique');
    } else {
      final advantage = timeFromP1 < timeFromP2 ? timeFromP2 - timeFromP1 : timeFromP1 - timeFromP2;
      print('OPTIMAL_START - Avantage significatif: ${advantage.toStringAsFixed(1)}s au $chosenSide');
    }
    
    return optimalPoint;
  }
  
  /// Détermine le point optimal de la ligne d'arrivée
  /// Choisit P1 ou P2 selon le temps de parcours minimal depuis la dernière position
  math.Point<double> _getOptimalFinishPoint(LineSegment finishLine, double lastX, double lastY) {
    final p1 = math.Point(finishLine.p1x, finishLine.p1y);
    final p2 = math.Point(finishLine.p2x, finishLine.p2y);
    
    // Calcul des temps de parcours réels vers chaque extrémité
    final timeToP1 = _estimateTimeToTarget(lastX, lastY, p1.x, p1.y);
    final timeToP2 = _estimateTimeToTarget(lastX, lastY, p2.x, p2.y);
    
    final optimalPoint = timeToP1 <= timeToP2 ? p1 : p2;
    final chosenSide = timeToP1 <= timeToP2 ? "P1" : "P2";
    
    print('OPTIMAL_FINISH - P1: (${p1.x.toStringAsFixed(1)}, ${p1.y.toStringAsFixed(1)}) temps=${timeToP1.toStringAsFixed(1)}s');
    print('OPTIMAL_FINISH - P2: (${p2.x.toStringAsFixed(1)}, ${p2.y.toStringAsFixed(1)}) temps=${timeToP2.toStringAsFixed(1)}s');
    print('OPTIMAL_FINISH - Choix: $chosenSide (temps optimal depuis dernière position)');
    
    // Vérifier l'écart de temps
    final timeDiff = (timeToP1 - timeToP2).abs();
    if (timeDiff < 5.0) { // Si moins de 5 secondes d'écart
      print('OPTIMAL_FINISH - Écart faible (${timeDiff.toStringAsFixed(1)}s), choix peu critique');
    } else {
      final advantage = timeToP1 < timeToP2 ? timeToP2 - timeToP1 : timeToP1 - timeToP2;
      print('OPTIMAL_FINISH - Avantage significatif: ${advantage.toStringAsFixed(1)}s au $chosenSide');
    }
    
    return optimalPoint;
  }

  /// Estime le temps de parcours entre deux points en tenant compte du vent et de la polaire
  double _estimateTimeToTarget(double startX, double startY, double endX, double endY) {
    if (windDirDeg == null || windSpeed == null) {
      // Pas de vent : utiliser vitesse par défaut (5 nds)
      final distance = math.sqrt(math.pow(endX - startX, 2) + math.pow(endY - startY, 2));
      return distance / 2.57; // 5 nds ≈ 2.57 m/s
    }

    final dx = endX - startX;
    final dy = endY - startY;
    final distance = math.sqrt(dx * dx + dy * dy);
    
    if (distance < 1e-6) return 0.0;

    // Direction géographique du segment (0°=Nord, 90°=Est)
    final courseDeg = (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
    
    // Angle par rapport au vent (TWA)
    final twa = signedDelta(courseDeg, windDirDeg!);
    final absTwa = twa.abs();

    // Obtenir la vitesse depuis la polaire
    double boatSpeed;
    if (polarData != null) {
      boatSpeed = polarData!.getSpeedForConditions(windSpeed!, absTwa);
    } else {
      // Polaire simplifiée si pas de données
      boatSpeed = _getSimplifiedBoatSpeed(windSpeed!, absTwa);
    }

    // Si c'est du près et qu'on ne peut pas remonter au vent, traitement spécial
    if (optimalUpwindAngle != null && absTwa < optimalUpwindAngle!) {
      // Route nécessite des bords - estimation approximative
      final tackingPenalty = 1.4; // 40% de temps en plus pour les bords
      boatSpeed = boatSpeed * 0.8; // Réduction de vitesse pour les manœuvres
      return (distance * tackingPenalty) / boatSpeed;
    }

    // Route directe possible
    return distance / boatSpeed;
  }

  /// Polaire simplifiée quand pas de données détaillées
  double _getSimplifiedBoatSpeed(double windSpeedKts, double absTwa) {
    // Vitesse de base proportionnelle au vent
    final baseSpeed = math.min(windSpeedKts * 0.4, 8.0); // Max 8 nds
    
    if (absTwa < 40) {
      // Près serré - vitesse réduite
      return baseSpeed * 0.6;
    } else if (absTwa < 60) {
      // Près bon - vitesse correcte  
      return baseSpeed * 0.85;
    } else if (absTwa < 120) {
      // Travers - vitesse maximale
      return baseSpeed * 1.0;
    } else if (absTwa < 150) {
      // Grand largue - vitesse élevée
      return baseSpeed * 0.95;
    } else {
      // Vent arrière - vitesse réduite
      return baseSpeed * 0.7;
    }
  }

  /// Génère un label avec l'angle de navigation
  String _createAngleLabel(double headingDeg, String segmentType) {
    return '$segmentType ${headingDeg.toStringAsFixed(0)}°';
  }

  List<RouteLeg> _routeLegWithTacksIfNeeded(double sx, double sy, double ex, double ey, {required String label, bool finish = false, WindTrendSnapshot? windTrend}) {
    // Pas de vent ou d'angle => segment direct
    if (windDirDeg == null || optimalUpwindAngle == null) {
      final estimatedTime = _estimateTimeToTarget(sx, sy, ex, ey);
      return [RouteLeg(startX: sx, startY: sy, endX: ex, endY: ey, type: finish ? RouteLegType.finish : RouteLegType.leg, label: label, estimatedTime: estimatedTime)];
    }
  final dx = ex - sx;
  final dy = ey - sy;
  final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1e-6) {
      return [];
    }
    // Heading géographique (0=N, 90=E) - coordonnées logiques Y vers le haut
    // Pour un bearing géographique standard : atan2(dx, dy) où dy est vers le Nord
    final headingRad = math.atan2(dx, dy);
    double headingDeg = (headingRad * 180 / math.pi) % 360;
    if (headingDeg < 0) headingDeg += 360;
    
    // Calcul du TWA théorique si on naviguait directement sur ce cap
    // TWA = angle entre direction du vent et cap requis 
    // TWA = windDir - heading (positif = vent de tribord, négatif = vent de bâbord)
    final theoreticalTWA = signedDelta(headingDeg, windDirDeg!); 
    final optimalAngle = optimalUpwindAngle!; // angle VMG optimal, pas de marge artificielle

    // Générer le label avec l'angle
    final angleLabel = _createAngleLabel(headingDeg, 'Cap');
    
    // Debug pour tous les segments
    final segmentLabel = label.contains('Start') ? '[START→B1]' : '[SEGMENT]';
    print('ROUTING DEBUG $segmentLabel - From: ($sx,$sy) To: ($ex,$ey), Vector: ($dx,$dy), Heading: $headingDeg°');
    
    // Debug routing decision
    final twaNature = theoreticalTWA.abs() < 45 ? "PRÈS" : theoreticalTWA.abs() < 135 ? "TRAVERS" : "PORTANT";
    print('ROUTING DEBUG - RequiredHeading: ${headingDeg.toStringAsFixed(1)}°, WindDir: ${windDirDeg!.toStringAsFixed(1)}°, TheoreticalTWA: ${theoreticalTWA.toStringAsFixed(1)}° ($twaNature), OptimalAngle: ${optimalAngle.toStringAsFixed(1)}°');
    
    // Décision de route directe vs manœuvres basée sur le TWA théorique:
    // - Au près (|TWA| < optimalAngle): faire des bords pour VMG optimal
    // - Au portant (|TWA| > 150°): faire des empannages si nécessaire 
    // - Au travers (optimalAngle <= |TWA| <= 150°): route directe
    
    final absTWA = theoreticalTWA.abs();
    
    if (absTWA >= optimalAngle && absTWA <= 150) {
      print('ROUTING - Route directe possible (TheoreticalTWA=${theoreticalTWA.toStringAsFixed(1)}° dans zone de navigation directe)');
      final estimatedTime = _estimateTimeToTarget(sx, sy, ex, ey);
      print('ROUTING DEBUG - Temps estimé pour segment direct: ${estimatedTime.toStringAsFixed(1)}s');
      return [RouteLeg(startX: sx, startY: sy, endX: ex, endY: ey, type: finish ? RouteLegType.finish : RouteLegType.leg, label: angleLabel, estimatedTime: estimatedTime)];
    }
    
    // Gérer les cas spéciaux : près et portant
    if (absTWA < optimalAngle) {
      print('ROUTING - Besoin de tirer des bords au près (TheoreticalTWA=${theoreticalTWA.toStringAsFixed(1)}° < ${optimalAngle.toStringAsFixed(1)}°)');
      return _createTackingLegs(sx, sy, ex, ey, windDirDeg!, optimalUpwindAngle!, dist, label, finish, windTrend);
    } else if (absTWA > 150) {
      print('ROUTING - Besoin d\'empanner au portant (TheoreticalTWA=${theoreticalTWA.toStringAsFixed(1)}° > 150°)');
      return _createJibingLegs(sx, sy, ex, ey, windDirDeg!, optimalUpwindAngle!, dist, label, finish, windTrend);
    }
    
    // Ne devrait pas arriver avec la logique mise à jour
    print('ROUTING - Cas non géré, route directe par défaut');
    final estimatedTime = _estimateTimeToTarget(sx, sy, ex, ey);
    return [RouteLeg(startX: sx, startY: sy, endX: ex, endY: ey, type: finish ? RouteLegType.finish : RouteLegType.leg, label: angleLabel, estimatedTime: estimatedTime)];
  }

  /// Crée des segments pour tirer des bords au près avec stratégie tactique basée sur la bascule
  List<RouteLeg> _createTackingLegs(double sx, double sy, double ex, double ey, 
      double windDir, double optimalAngle, double dist, String label, bool finish, WindTrendSnapshot? windTrend) {
    
    // Caps au près optimaux
    final h1 = norm360(windDir + optimalAngle); // tribord (vent sur tribord)
    final h2 = norm360(windDir - optimalAngle); // bâbord (vent sur bâbord)
    final v1 = vectorFromBearing(h1, screenYAxisDown: false); // tribord
    final v2 = vectorFromBearing(h2, screenYAxisDown: false); // bâbord
    
    // Vecteur vers la cible
    final dx = ex - sx;
    final dy = ey - sy;
    final targetVec = math.Point(dx, dy);
    
    // **NOUVELLE LOGIQUE TACTIQUE** : Choix du bord basé sur la bascule de vent
    bool startWithLeftTack = false; // Par défaut : tribord
    String tackReason = "Défaut";
    
    if (windTrend != null) {
      if (windTrend.trend == WindTrendDirection.backingLeft) {
        // Bascule à gauche → partir à gauche (bâbord)
        startWithLeftTack = true;
        tackReason = "Bascule gauche";
      } else if (windTrend.trend == WindTrendDirection.veeringRight) {
        // Bascule à droite → partir à droite (tribord)
        startWithLeftTack = false;
        tackReason = "Bascule droite";
      } else {
        // Pas de bascule claire → meilleure projection (logique actuelle)
        double proj1 = (targetVec.x * v1.x + targetVec.y * v1.y);
        double proj2 = (targetVec.x * v2.x + targetVec.y * v2.y);
        startWithLeftTack = proj2 > proj1;
        tackReason = "Projection optimale";
      }
    } else {
      // Pas de données de vent → meilleure projection
      double proj1 = (targetVec.x * v1.x + targetVec.y * v1.y);
      double proj2 = (targetVec.x * v2.x + targetVec.y * v2.y);
      startWithLeftTack = proj2 > proj1;
      tackReason = "Pas de bascule";
    }
    
    final firstVec = startWithLeftTack ? v2 : v1;
    final firstHeading = startWithLeftTack ? h2 : h1;
    final secondVec = startWithLeftTack ? v1 : v2;
    final secondHeading = startWithLeftTack ? h1 : h2;
    final firstTack = startWithLeftTack ? "Bâbord" : "Tribord";
    final secondTack = startWithLeftTack ? "Tribord" : "Bâbord";
    
    print('TACKING DEBUG - Start: ($sx,$sy) Target: ($ex,$ey)');
    print('TACKING DEBUG - Choix tactique: $firstTack (${firstHeading.toStringAsFixed(1)}°) - Raison: $tackReason');
    if (windTrend != null) {
      print('TACKING DEBUG - Bascule détectée: ${windTrend.trend}');
    }
    
    // **CALCUL GÉOMÉTRIQUE CORRECT DU POINT DE VIREMENT**
    // Utilisation des laylines : calculer l'intersection des laylines des deux amures
    
    // Layline depuis la cible sur l'amure opposée au premier bord
    final targetLaylineVec = startWithLeftTack ? v1 : v2; // Si on commence à bâbord, la layline cible est tribord
    
    // Résolution géométrique : intersection de deux droites
    // Droite 1 : position actuelle + t1 * firstVec (premier bord)  
    // Droite 2 : cible - t2 * targetLaylineVec (layline cible)
    // 
    // sx + t1 * firstVec.x = ex - t2 * targetLaylineVec.x
    // sy + t1 * firstVec.y = ey - t2 * targetLaylineVec.y
    //
    // Système 2x2 : résoudre pour t1
    
    final det = firstVec.x * targetLaylineVec.y - firstVec.y * targetLaylineVec.x;
    
    double wp1x, wp1y;
    
    if (det.abs() < 1e-6) {
      // Droites parallèles (cas dégénéré) - fallback sur distance proportionnelle
      print('TACKING DEBUG - Laylines parallèles, utilisation fallback');
      final proj = (targetVec.x * firstVec.x + targetVec.y * firstVec.y);
      final fallbackDist = math.max(dist * 0.5, proj * 0.75);
      wp1x = sx + firstVec.x * fallbackDist;
      wp1y = sy + firstVec.y * fallbackDist;
    } else {
      // Intersection géométrique exacte
      final dx_target = ex - sx;
      final dy_target = ey - sy;
      
      final t1 = (dx_target * targetLaylineVec.y - dy_target * targetLaylineVec.x) / det;
      
      // Limiter t1 pour éviter des distances excessives
      final maxT1 = dist * 1.2; // Maximum 120% de la distance directe
      final minT1 = dist * 0.3; // Minimum 30% de la distance directe
      final limitedT1 = t1.clamp(minT1, maxT1);
      
      wp1x = sx + firstVec.x * limitedT1;
      wp1y = sy + firstVec.y * limitedT1;
      
      if (t1 != limitedT1) {
        print('TACKING DEBUG - T1 limité : ${t1.toStringAsFixed(1)} -> ${limitedT1.toStringAsFixed(1)}');
      }
    }
    
    print('TACKING DEBUG - First leg: ($sx,$sy) -> (${wp1x.toStringAsFixed(1)},${wp1y.toStringAsFixed(1)}) ($firstTack)');
    
    // Vérifier l'angle du second bord
    final dx2 = ex - wp1x;
    final dy2 = ey - wp1y;
    final distToTarget = math.sqrt(dx2 * dx2 + dy2 * dy2);
    final headingToTarget = math.atan2(dx2, dy2) * 180 / math.pi;
    final normalizedHeadingToTarget = headingToTarget < 0 ? headingToTarget + 360 : headingToTarget;
    final twaToTarget = signedDelta(windDir, normalizedHeadingToTarget).abs();
    
    print('TACKING DEBUG - From tack point to target: heading=${normalizedHeadingToTarget.toStringAsFixed(1)}°, TWA=${twaToTarget.toStringAsFixed(1)}°');
    
    final legs = <RouteLeg>[];
    
    // Premier bord
    final firstLegTime = _estimateTimeToTarget(sx, sy, wp1x, wp1y);
    legs.add(RouteLeg(
      startX: sx, startY: sy, endX: wp1x, endY: wp1y,
      type: RouteLegType.leg,
      label: _createAngleLabel(firstHeading, 'Près'),
      estimatedTime: firstLegTime,
    ));
    
    // Second segment : soit au près soit direct
    final secondLegTime = _estimateTimeToTarget(wp1x, wp1y, ex, ey);
    if (twaToTarget >= optimalAngle + 5) {
      // Route directe possible
      final segmentType = twaToTarget > 150 ? 'Portant' : 'Cap';
      legs.add(RouteLeg(
        startX: wp1x, startY: wp1y, endX: ex, endY: ey,
        type: finish ? RouteLegType.finish : RouteLegType.leg,
        label: _createAngleLabel(normalizedHeadingToTarget, segmentType),
        estimatedTime: secondLegTime,
      ));
      print('TACKING DEBUG - Second leg: direct to target (${segmentType} ${normalizedHeadingToTarget.toStringAsFixed(1)}°)');
    } else {
      // Second bord au près nécessaire
      legs.add(RouteLeg(
        startX: wp1x, startY: wp1y, endX: ex, endY: ey,
        type: finish ? RouteLegType.finish : RouteLegType.leg,
        label: _createAngleLabel(secondHeading, 'Près'),
        estimatedTime: secondLegTime,
      ));
      print('TACKING DEBUG - Second leg: tacking to target ($secondTack ${secondHeading.toStringAsFixed(1)}°)');
    }
    
    print('TACKING DEBUG - Generated ${legs.length} legs (layline intersection method)');
    return legs;
  }

  /// Crée des segments pour empanner au portant
  List<RouteLeg> _createJibingLegs(double sx, double sy, double ex, double ey, 
      double windDir, double optimalAngle, double dist, String label, bool finish, WindTrendSnapshot? windTrend) {
    
    // Au portant, angle optimal typiquement 140-160° TWA
    final optimalDownwindAngle = 150.0;
    
    // Caps au portant optimaux  
    final h1 = norm360(windDir + optimalDownwindAngle); // tribord portant
    final h2 = norm360(windDir - optimalDownwindAngle); // bâbord portant
    final v1 = vectorFromBearing(h1, screenYAxisDown: false);
    final v2 = vectorFromBearing(h2, screenYAxisDown: false);
    
    final dx = ex - sx;
    final dy = ey - sy;
    final targetVec = math.Point(dx, dy);
    
    // **LOGIQUE TACTIQUE PORTANT** : même principe qu'au près
    bool startWithLeftJibe = false; // Par défaut : tribord
    String jibeReason = "Défaut";
    
    if (windTrend != null) {
      if (windTrend.trend == WindTrendDirection.backingLeft) {
        // Bascule à gauche → partir à gauche (bâbord) au portant aussi
        startWithLeftJibe = true;
        jibeReason = "Bascule gauche";
      } else if (windTrend.trend == WindTrendDirection.veeringRight) {
        // Bascule à droite → partir à droite (tribord) au portant
        startWithLeftJibe = false;
        jibeReason = "Bascule droite";
      } else {
        // Pas de bascule → meilleure projection
        double proj1 = (targetVec.x * v1.x + targetVec.y * v1.y);
        double proj2 = (targetVec.x * v2.x + targetVec.y * v2.y);
        startWithLeftJibe = proj2 > proj1;
        jibeReason = "Projection optimale";
      }
    } else {
      // Pas de données → meilleure projection
      double proj1 = (targetVec.x * v1.x + targetVec.y * v1.y);
      double proj2 = (targetVec.x * v2.x + targetVec.y * v2.y);
      startWithLeftJibe = proj2 > proj1;
      jibeReason = "Pas de bascule";
    }
    
    final firstVec = startWithLeftJibe ? v2 : v1;
    final firstHeading = startWithLeftJibe ? h2 : h1;
    final firstSide = startWithLeftJibe ? "bâbord" : "tribord";
    
    print('JIBING DEBUG - Choix tactique portant: $firstSide (${firstHeading.toStringAsFixed(1)}°) - Raison: $jibeReason');
    
    // Distance du premier portant (plus conservateur qu'au près)
    final leg1Dist = dist * 0.4;
    final wp1x = sx + firstVec.x * leg1Dist;
    final wp1y = sy + firstVec.y * leg1Dist;
    
    // Calculer l'angle du second segment
    final dx2 = ex - wp1x;
    final dy2 = ey - wp1y;
    final heading2Rad = math.atan2(dx2, dy2);
    double heading2 = (heading2Rad * 180 / math.pi) % 360;
    if (heading2 < 0) heading2 += 360;
    
    final firstJibeLegTime = _estimateTimeToTarget(sx, sy, wp1x, wp1y);
    final secondJibeLegTime = _estimateTimeToTarget(wp1x, wp1y, ex, ey);
    
    return [
      RouteLeg(startX: sx, startY: sy, endX: wp1x, endY: wp1y, 
              type: RouteLegType.leg, label: _createAngleLabel(firstHeading, 'Portant'),
              estimatedTime: firstJibeLegTime),
      RouteLeg(startX: wp1x, startY: wp1y, endX: ex, endY: ey, 
              type: finish ? RouteLegType.finish : RouteLegType.leg, label: _createAngleLabel(heading2, 'Portant'),
              estimatedTime: secondJibeLegTime),
    ];
  }

  double _angleDiff(double a, double b) => ((a - b + 540) % 360) - 180; // legacy (kept for backward compat callers)
}
