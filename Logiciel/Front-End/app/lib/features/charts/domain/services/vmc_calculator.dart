import 'dart:math' as math;

import '../models/polar_table.dart';

/// Calcule les angles optimaux de progression (près / portant) à partir d'une table de polaires.
class VmcCalculator {
  /// Retourne le meilleur angle dans [angleStart, angleEnd) avec step degrés.
  /// modeUpwind: si true, VMG = v * cos(angle); sinon VMG = v * cos(pi - angle).
  VmcResult? bestAngle({
    required PolarTable table,
    required double targetWindSpeed,
    required int angleStart,
    required int angleEnd,
    required int step,
    required bool upwind,
  }) {
    double? bestVmg;
    double? bestAngleDeg;
    double? bestSpeed;

    for (int ang = angleStart; ang < angleEnd; ang += step) {
      final speed = table.nearest(ang.toDouble(), targetWindSpeed);
      if (speed == null || speed <= 0) continue;
      // angle relatif pour la projection
  final rad = (upwind ? ang : (180 - ang)) * (math.pi / 180.0);
  final vmg = speed * math.cos(rad);
      if (vmg <= 0) continue; // ignore si composante négative
      if (bestVmg == null || vmg > bestVmg) {
        bestVmg = vmg;
        bestAngleDeg = ang.toDouble();
        bestSpeed = speed;
      }
    }
    if (bestVmg == null || bestAngleDeg == null || bestSpeed == null) return null;
    return VmcResult(angleDeg: bestAngleDeg, speed: bestSpeed, vmg: bestVmg);
  }

  VmcResult? bestUpwind(PolarTable table, double wind) => bestAngle(
        table: table,
        targetWindSpeed: wind,
        angleStart: 30,
        angleEnd: 95,
        step: 5,
        upwind: true,
      );

  VmcResult? bestDownwind(PolarTable table, double wind) => bestAngle(
        table: table,
        targetWindSpeed: wind,
        angleStart: 95,
        angleEnd: 181,
        step: 5,
        upwind: false,
      );
}

// (Simplifié: on utilise directement dart:math)
