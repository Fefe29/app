import 'dart:math' as math;

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

  RoutingCalculator({this.windDirDeg, this.optimalUpwindAngle});

  RoutePlan compute(CourseState course, {WindTrendSnapshot? windTrend}) {
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

    // Ajout bouée target si distincte (et pas déjà dernière position)
    if (target != null) {
      if (curX != null && (curX != target.x || curY != target.y)) {
        final seg = _routeLegWithTacksIfNeeded(curX!, curY!, target.x, target.y, label: '->Vis');
        legs.addAll(seg);
        curX = target.x;
        curY = target.y;
      }
    }

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
    final headingRad = math.atan2(dx, dy * -1); // approximation dépendant convention; ajuster si besoin.
    double headingDeg = (headingRad * 180 / math.pi) % 360;
    if (headingDeg < 0) headingDeg += 360;
    // TWA signé: différence entre heading et vent FROM
    final diff = _angleDiff(headingDeg, windDirDeg!); // en degrés [-180,180]
    final twaAbs = diff.abs();
    final minUp = optimalUpwindAngle! - 3; // marge 3°
    if (twaAbs >= minUp) {
      // segment navigable directement
      return [RouteLeg(startX: sx, startY: sy, endX: ex, endY: ey, type: finish ? RouteLegType.finish : RouteLegType.leg, label: label)];
    }
    // Besoin de 2 bords. Choisir d'abord bord qui réduit l'écart latéral.
    // Calculer vecteurs laylines (windDir ± optimalUpwindAngle)
    final h1 = (windDirDeg! - optimalUpwindAngle!) % 360;
    final h2 = (windDirDeg! + optimalUpwindAngle!) % 360;
    // Convertir en vecteurs unitaires (x=sin, y=-cos)
    math.Point<double> _vec(double deg) {
      final r = deg * math.pi / 180;
      return math.Point(math.sin(r), -math.cos(r));
    }
    final v1 = _vec(h1);
    final v2 = _vec(h2);
  final targetVec = math.Point(dx, dy);
    // Choix: vecteur avec projection scalaire la plus grande sur target (pour avancer vers la cible)
  double proj1 = (targetVec.x * v1.x + targetVec.y * v1.y);
  double proj2 = (targetVec.x * v2.x + targetVec.y * v2.y);
    // Longueur raisonnable du premier bord: limiter à 60% de la distance ou jusqu'à alignement latéral.
  final firstVec = proj1 >= proj2 ? v1 : v2;
  final secondVec = proj1 >= proj2 ? v2 : v1; // secondVec non utilisé pour MVP mais conservé future optimisation
    // Distance première jambe: heuristique - aller jusqu'à ce que la projection latérale sur l'autre bord permette de fermer.
    final leg1Dist = dist * 0.55; // heuristique simple
  final wp1x = sx + firstVec.x * leg1Dist;
  final wp1y = sy + firstVec.y * leg1Dist;
    // Vérifier si la deuxième jambe encore face au vent -> si oui ajuster (simple: allonge un peu)
    double dx2 = ex - wp1x;
    double dy2 = ey - wp1y;
    final heading2Rad = math.atan2(dx2, dy2 * -1);
    double heading2Deg = (heading2Rad * 180 / math.pi) % 360;
    if (heading2Deg < 0) heading2Deg += 360;
    final twa2 = _angleDiff(heading2Deg, windDirDeg!).abs();
    if (twa2 < minUp && dist > 20) {
      // Allonger première jambe
      final extra = dist * 0.15;
  final wp1x2 = sx + firstVec.x * (leg1Dist + extra);
  final wp1y2 = sy + firstVec.y * (leg1Dist + extra);
      dx2 = ex - wp1x2;
      dy2 = ey - wp1y2;
      // remplacer waypoint
      return [
        RouteLeg(startX: sx, startY: sy, endX: wp1x2, endY: wp1y2, type: RouteLegType.leg, label: 'Tack1'),
        RouteLeg(startX: wp1x2, startY: wp1y2, endX: ex, endY: ey, type: finish ? RouteLegType.finish : RouteLegType.leg, label: label),
      ];
    }
    return [
      RouteLeg(startX: sx, startY: sy, endX: wp1x, endY: wp1y, type: RouteLegType.leg, label: 'Tack1'),
      RouteLeg(startX: wp1x, startY: wp1y, endX: ex, endY: ey, type: finish ? RouteLegType.finish : RouteLegType.leg, label: label),
    ];
  }

  double _angleDiff(double a, double b) {
    double d = (a - b + 540) % 360 - 180; // [-180,180]
    return d;
  }
}
