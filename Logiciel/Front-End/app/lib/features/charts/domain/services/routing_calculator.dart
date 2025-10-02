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
  });
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final RouteLegType type;
  final String? label; // ex: "B2->B3"
}

class RoutePlan {
  RoutePlan(this.legs);
  final List<RouteLeg> legs;
  bool get isEmpty => legs.isEmpty;
}

/// Calculateur de routage très simple (MVP) :
/// - Point de départ = milieu de la ligne de départ si disponible sinon première bouée.
/// - Ordre des bouées = tri par passageOrder (croissant) puis par id croissant pour celles sans passageOrder.
/// - Ajoute éventuellement la bouée "target" (viseur) à la fin si elle existe et n'est pas déjà dans la séquence.
/// - Point final = milieu de la ligne d'arrivée si présent.
/// Ne calcule pas encore des laylines / VMG optimisés : cette partie viendra ensuite.
class RoutingCalculator {
  double? windDirDeg; // FROM direction en degrés (injecté optionnellement)
  double? optimalUpwindAngle; // angle TWA optimum (ex: 40°)
  double? currentTwaSigned; // TWA signé courant (-180..180) provenant télémétrie

  RoutingCalculator({this.windDirDeg, this.optimalUpwindAngle, this.currentTwaSigned});

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

    // Point de départ : milieu de la ligne de départ sinon première bouée sinon rien
    double? curX;
    double? curY;
    if (course.startLine != null) {
      curX = (course.startLine!.p1x + course.startLine!.p2x) / 2;
      curY = (course.startLine!.p1y + course.startLine!.p2y) / 2;
    } else if (regular.isNotEmpty) {
      curX = regular.first.x;
      curY = regular.first.y;
    }

    // Ajoute segment fictif début -> première bouée seulement si départ existe et qu'on a des bouées
    // Détermination d'un éventuel segment stratégique avant d'aller à la première bouée
    if (course.startLine != null && regular.isNotEmpty) {
      final first = regular.first;
      final startMidX = curX!; // non null ici
      final startMidY = curY!;

      // Calcul vecteur vers la première bouée
      final vx = first.x - startMidX;
      final vy = first.y - startMidY;
      final distFirst = math.sqrt(vx * vx + vy * vy);

      bool addedStrategic = false;
      if (windTrend != null && windTrend.isReliable && distFirst > 1e-3) {
        // Pour MVP : appliquer logique stratégique dès qu'une rotation fiable est détectée.
        if (windTrend.trend == WindTrendDirection.veeringRight || windTrend.trend == WindTrendDirection.backingLeft) {
          final sens = windTrend.sensitivity.clamp(0.0, 1.0);
            // Offset proportionnel à la distance (ex: 20% à 35% selon sensibilité)
          final offsetFactor = 0.2 + 0.15 * sens;
          final offsetDist = distFirst * offsetFactor;

          // Choix côté : veeringRight => aller à droite (tribord) ; backingLeft => gauche (bâbord)
          // Pour définir droite/gauche on prend un vecteur perpendiculaire au vent supposé moyen.
          // Sans vent absolu ici, on utilise la perpendiculaire du segment vers la bouée comme proxy.
          // Perp (vx,vy) -> (vy,-vx)
          double px = vy;
          double py = -vx;
          final normP = math.sqrt(px * px + py * py);
          if (normP > 1e-6) {
            px /= normP;
            py /= normP;
          }
          if (windTrend.trend == WindTrendDirection.backingLeft) {
            // Inverser côté
            px = -px;
            py = -py;
          }
          final waypointX = startMidX + px * offsetDist;
          final waypointY = startMidY + py * offsetDist;
          legs.add(RouteLeg(
            startX: startMidX,
            startY: startMidY,
            endX: waypointX,
            endY: waypointY,
            type: RouteLegType.start,
            label: windTrend.trend == WindTrendDirection.veeringRight ? 'Strat droite' : 'Strat gauche',
          ));
          legs.add(RouteLeg(
            startX: waypointX,
            startY: waypointY,
            endX: first.x,
            endY: first.y,
            type: RouteLegType.leg,
            label: '->B${first.id}',
          ));
          curX = first.x;
          curY = first.y;
          addedStrategic = true;
        }
      }

      if (!addedStrategic) {
        // Fallback route directe
        legs.add(RouteLeg(
          startX: startMidX,
          startY: startMidY,
          endX: first.x,
          endY: first.y,
          type: RouteLegType.start,
          label: 'Start->B${first.id}',
        ));
        curX = first.x;
        curY = first.y;
      }
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
      final seg = _routeLegWithTacksIfNeeded(curX, curY, b.x, b.y, label: 'B->B${b.id}');
      legs.addAll(seg);
      curX = b.x;
      curY = b.y;
    }

    // Le viseur (target) ne fait pas partie de la séquence de course
    // Il sert uniquement pour la ligne de départ
    // Nous ne l'ajoutons donc pas dans le routage

    // Arrivée
    if (course.finishLine != null && curX != null && curY != null) {
      final fx = (course.finishLine!.p1x + course.finishLine!.p2x) / 2;
      final fy = (course.finishLine!.p1y + course.finishLine!.p2y) / 2;
      if (fx != curX || fy != curY) {
        final seg = _routeLegWithTacksIfNeeded(curX, curY, fx, fy, label: 'Finish', finish: true);
        legs.addAll(seg);
      }
    }

    // NOTE: Pour une future extension, on pourrait insérer ici une divergence stratégique
    // sur le premier bord si trend veering/backing pour exploiter la rotation.
    // (Ex: ajouter un waypoint artificiel vers la droite/gauche avant de rejoindre la première bouée.)
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

  List<RouteLeg> _routeLegWithTacksIfNeeded(double sx, double sy, double ex, double ey, {required String label, bool finish = false}) {
    // Pas de vent ou d'angle => segment direct
    if (windDirDeg == null || optimalUpwindAngle == null) {
      return [RouteLeg(startX: sx, startY: sy, endX: ex, endY: ey, type: finish ? RouteLegType.finish : RouteLegType.leg, label: label)];
    }
  final dx = ex - sx;
  final dy = ey - sy;
  final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1e-6) {
      return [];
    }
    // Heading géographique (0=N, 90=E) cohérent avec usage écran: inverser Y si repère différent?
    // Nous supposons ici que Y croît vers le haut dans les données logique (cf projection). Heading calcul:
    // Coordonnées logiques: X droite (Est), Y haut (Nord). Bearing géographique via util.
    final headingDeg = bearingFromVector(dx, dy, screenYAxisDown: false);
    
    // Debug spécial pour segment départ → B1  
    print('ROUTING DEBUG - From: ($sx,$sy) To: ($ex,$ey), Vector: ($dx,$dy), Heading: $headingDeg°');
    // Calcul du TWA théorique si on naviguait directement sur ce cap
    // TWA = angle entre direction du vent et cap requis 
    // TWA = windDir - heading (positif = vent de tribord, négatif = vent de bâbord)
    final theoreticalTWA = signedDelta(headingDeg, windDirDeg!); 
    final minUp = optimalUpwindAngle! - 3; // marge pour navigation au près
    
    // Debug routing decision
    final twaNature = theoreticalTWA.abs() < 45 ? "PRÈS" : theoreticalTWA.abs() < 135 ? "TRAVERS" : "PORTANT";
    print('ROUTING DEBUG - RequiredHeading: ${headingDeg.toStringAsFixed(1)}°, WindDir: ${windDirDeg!.toStringAsFixed(1)}°, TheoreticalTWA: ${theoreticalTWA.toStringAsFixed(1)}° ($twaNature), MinAngle: ${minUp.toStringAsFixed(1)}°');
    
    // Décision de route directe vs manœuvres basée sur le TWA théorique:
    // - Au près (|TWA| < minUp): faire des bords
    // - Au portant (|TWA| > 150°): faire des empannages si nécessaire 
    // - Au travers (minUp <= |TWA| <= 150°): route directe
    
    final absTWA = theoreticalTWA.abs();
    
    if (absTWA >= minUp && absTWA <= 150) {
      print('ROUTING - Route directe possible (TheoreticalTWA=${theoreticalTWA.toStringAsFixed(1)}° dans zone de navigation directe)');
      return [RouteLeg(startX: sx, startY: sy, endX: ex, endY: ey, type: finish ? RouteLegType.finish : RouteLegType.leg, label: label)];
    }
    
    // Gérer les cas spéciaux : près et portant
    if (absTWA < minUp) {
      print('ROUTING - Besoin de tirer des bords au près (TheoreticalTWA=${theoreticalTWA.toStringAsFixed(1)}° < ${minUp.toStringAsFixed(1)}°)');
      return _createTackingLegs(sx, sy, ex, ey, windDirDeg!, optimalUpwindAngle!, dist, label, finish);
    } else if (absTWA > 150) {
      print('ROUTING - Besoin d\'empanner au portant (TheoreticalTWA=${theoreticalTWA.toStringAsFixed(1)}° > 150°)');
      return _createJibingLegs(sx, sy, ex, ey, windDirDeg!, optimalUpwindAngle!, dist, label, finish);
    }
    
    // Ne devrait pas arriver avec la logique mise à jour
    print('ROUTING - Cas non géré, route directe par défaut');
    return [RouteLeg(startX: sx, startY: sy, endX: ex, endY: ey, type: finish ? RouteLegType.finish : RouteLegType.leg, label: label)];
  }

  /// Crée des segments pour tirer des bords au près
  List<RouteLeg> _createTackingLegs(double sx, double sy, double ex, double ey, 
      double windDir, double optimalAngle, double dist, String label, bool finish) {
    
    // Caps au près optimaux
    final h1 = norm360(windDir + optimalAngle); // tribord (vent sur tribord)
    final h2 = norm360(windDir - optimalAngle); // bâbord (vent sur bâbord)
    final v1 = vectorFromBearing(h1, screenYAxisDown: false); // tribord
    final v2 = vectorFromBearing(h2, screenYAxisDown: false); // bâbord
    
    final dx = ex - sx;
    final dy = ey - sy;
    final targetVec = math.Point(dx, dy);
    
    // Choix du meilleur bord initial (projection maximale vers la cible)
    double proj1 = (targetVec.x * v1.x + targetVec.y * v1.y);
    double proj2 = (targetVec.x * v2.x + targetVec.y * v2.y);
    
    final firstVec = proj1 >= proj2 ? v1 : v2;
    final firstSide = proj1 >= proj2 ? "tribord" : "bâbord";
    
    // Distance du premier bord (heuristique : 50-60% de la distance totale)
    final leg1Dist = dist * 0.6;
    final wp1x = sx + firstVec.x * leg1Dist;
    final wp1y = sy + firstVec.y * leg1Dist;
    
    // Vérifier si le second segment peut fermer directement
    final dx2 = ex - wp1x;
    final dy2 = ey - wp1y;
    final heading2 = bearingFromVector(dx2, dy2, screenYAxisDown: false);
    final twa2 = signedDelta(windDir, heading2).abs();
    
    if (twa2 < optimalAngle - 5 && dist > 15) {
      // Allonger le premier bord
      final extraDist = dist * 0.25;
      final wp1x2 = sx + firstVec.x * (leg1Dist + extraDist);
      final wp1y2 = sy + firstVec.y * (leg1Dist + extraDist);
      
      return [
        RouteLeg(startX: sx, startY: sy, endX: wp1x2, endY: wp1y2, 
                type: RouteLegType.leg, label: 'Bord $firstSide'),
        RouteLeg(startX: wp1x2, startY: wp1y2, endX: ex, endY: ey, 
                type: finish ? RouteLegType.finish : RouteLegType.leg, label: label),
      ];
    }
    
    return [
      RouteLeg(startX: sx, startY: sy, endX: wp1x, endY: wp1y, 
              type: RouteLegType.leg, label: 'Bord $firstSide'),
      RouteLeg(startX: wp1x, startY: wp1y, endX: ex, endY: ey, 
              type: finish ? RouteLegType.finish : RouteLegType.leg, label: label),
    ];
  }

  /// Crée des segments pour empanner au portant
  List<RouteLeg> _createJibingLegs(double sx, double sy, double ex, double ey, 
      double windDir, double optimalAngle, double dist, String label, bool finish) {
    
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
    
    // Choix du meilleur côté initial
    double proj1 = (targetVec.x * v1.x + targetVec.y * v1.y);
    double proj2 = (targetVec.x * v2.x + targetVec.y * v2.y);
    
    final firstVec = proj1 >= proj2 ? v1 : v2;
    final firstSide = proj1 >= proj2 ? "tribord" : "bâbord";
    
    // Distance du premier portant (plus conservateur qu'au près)
    final leg1Dist = dist * 0.4;
    final wp1x = sx + firstVec.x * leg1Dist;
    final wp1y = sy + firstVec.y * leg1Dist;
    
    return [
      RouteLeg(startX: sx, startY: sy, endX: wp1x, endY: wp1y, 
              type: RouteLegType.leg, label: 'Portant $firstSide'),
      RouteLeg(startX: wp1x, startY: wp1y, endX: ex, endY: ey, 
              type: finish ? RouteLegType.finish : RouteLegType.leg, label: label),
    ];
  }

  double _angleDiff(double a, double b) => ((a - b + 540) % 360) - 180; // legacy (kept for backward compat callers)
}
