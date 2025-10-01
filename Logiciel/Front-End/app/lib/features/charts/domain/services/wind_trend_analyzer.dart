import 'dart:collection';
import 'dart:math' as math;

import 'package:kornog/common/providers/app_providers.dart' show WindSample;

/// Classification de la tendance globale du vent.
enum WindTrendDirection { veeringRight, backingLeft, neutral, irregular }

class WindTrendSnapshot {
  WindTrendSnapshot({
    required this.trend,
    required this.linearSlopeDegPerMin,
    required this.supportPoints,
    required this.windowSeconds,
    required this.sensitivity,
  });
  final WindTrendDirection trend;
  final double linearSlopeDegPerMin; // pente régression linéaire (deg/min)
  final int supportPoints; // nb d'échantillons utilisés
  final int windowSeconds; // taille de la fenêtre
  final double sensitivity; // paramètre de filtrage (0..1)
  bool get isReliable => supportPoints > 8; // heuristique simple
}

/// Analyse la tendance (rotation progressive) vs irrégularité (oscillation) du vent.
/// Paramètres de filtrage :
/// - windowSeconds: durée de la fenêtre d'analyse
/// - minSlopeDegPerMin: pente minimale (après normalisation par sensibilité) pour considérer 'rotation'
/// - oscillationThresholdDeg: amplitude max acceptable pour dire qu'on a une rotation relativement régulière
class WindTrendAnalyzer {
  WindTrendAnalyzer({
    required this.windowSeconds,
    required this.minSlopeDegPerMinBase,
    required this.oscillationThresholdDegBase,
    required this.sensitivity, // 0 = peu sensible (nécessite forte pente), 1 = très sensible
  }) : assert(sensitivity >= 0 && sensitivity <= 1);

  final int windowSeconds;
  final double minSlopeDegPerMinBase;
  final double oscillationThresholdDegBase;
  final double sensitivity; // ajuste dynamiquement les seuils

  final Queue<_TimedDir> _samples = Queue();

  WindTrendSnapshot ingest(WindSample sample) {
    final now = DateTime.now();
    _samples.add(_TimedDir(now, sample.directionDeg));
    final cutoff = now.subtract(Duration(seconds: windowSeconds));
    while (_samples.isNotEmpty && _samples.first.time.isBefore(cutoff)) {
      _samples.removeFirst();
    }
    if (_samples.length < 5) {
      return WindTrendSnapshot(
        trend: WindTrendDirection.neutral,
        linearSlopeDegPerMin: 0,
        supportPoints: _samples.length,
        windowSeconds: windowSeconds,
        sensitivity: sensitivity,
      );
    }
    // Régression linéaire simple sur (t, dir). Normaliser t en minutes relative.
    final firstT = _samples.first.time;
    final xs = <double>[];
    final ys = <double>[];
    for (final s in _samples) {
      xs.add(s.time.difference(firstT).inMilliseconds / 60000.0); // minutes
      ys.add(s.dir);
    }
    final slope = _linearSlope(xs, ys); // deg/min
    final minSlope = _adjustMinSlope();
    final oscillation = _oscillationAmplitude(ys);
    final maxOsc = _adjustOscThreshold();

    WindTrendDirection trend;
    if (oscillation > maxOsc) {
      trend = WindTrendDirection.irregular;
    } else if (slope > minSlope) {
      trend = WindTrendDirection.veeringRight; // tourne à droite (angle augmente)
    } else if (slope < -minSlope) {
      trend = WindTrendDirection.backingLeft; // tourne à gauche (angle diminue)
    } else {
      trend = WindTrendDirection.neutral;
    }
    return WindTrendSnapshot(
      trend: trend,
      linearSlopeDegPerMin: slope,
      supportPoints: _samples.length,
      windowSeconds: windowSeconds,
      sensitivity: sensitivity,
    );
  }

  double _linearSlope(List<double> xs, List<double> ys) {
    final n = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;
    double num = 0, den = 0;
    for (var i = 0; i < n; i++) {
      final dx = xs[i] - meanX;
      num += dx * (ys[i] - meanY);
      den += dx * dx;
    }
    if (den.abs() < 1e-9) return 0;
    return num / den;
  }

  double _oscillationAmplitude(List<double> ys) {
    if (ys.isEmpty) return 0;
    final minV = ys.reduce(math.min);
    final maxV = ys.reduce(math.max);
    return maxV - minV; // amplitude brute
  }

  double _adjustMinSlope() {
    // Plus la sensibilité est élevée, plus on accepte une pente faible => multiplier par (1 - 0.7*sensitivity)
    return minSlopeDegPerMinBase * (1 - 0.7 * sensitivity);
  }

  double _adjustOscThreshold() {
    // Plus la sensibilité est élevée, plus on tolère moins d'oscillation => diviser par (1 + 0.5*sens)
    return oscillationThresholdDegBase / (1 + 0.5 * sensitivity);
  }
}

class _TimedDir {
  _TimedDir(this.time, this.dir);
  final DateTime time;
  final double dir;
}
