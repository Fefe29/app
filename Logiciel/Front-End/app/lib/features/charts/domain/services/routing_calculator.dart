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
      legs.add(RouteLeg(
        startX: curX,
        startY: curY,
        endX: b.x,
        endY: b.y,
        type: RouteLegType.leg,
        label: 'B->B${b.id}',
      ));
      curX = b.x;
      curY = b.y;
    }

    // Ajout bouée target si distincte (et pas déjà dernière position)
    if (target != null) {
      if (curX != null && (curX != target.x || curY != target.y)) {
        legs.add(RouteLeg(
          startX: curX!,
            startY: curY!,
            endX: target.x,
            endY: target.y,
            type: RouteLegType.leg,
            label: '->Vis',
        ));
        curX = target.x;
        curY = target.y;
      }
    }

    // Arrivée
    if (course.finishLine != null && curX != null && curY != null) {
      final fx = (course.finishLine!.p1x + course.finishLine!.p2x) / 2;
      final fy = (course.finishLine!.p1y + course.finishLine!.p2y) / 2;
      if (fx != curX || fy != curY) {
        legs.add(RouteLeg(
          startX: curX,
          startY: curY,
          endX: fx,
          endY: fy,
          type: RouteLegType.finish,
          label: 'Finish',
        ));
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
}
