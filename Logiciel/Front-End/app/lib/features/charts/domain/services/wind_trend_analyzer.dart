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
    required this.actualDataDurationSeconds, // durée réelle des données collectées
  });
  final WindTrendDirection trend;
  final double linearSlopeDegPerMin; // pente régression linéaire (deg/min)
  final int supportPoints; // nb d'échantillons utilisés
  final int windowSeconds; // taille de la fenêtre demandée
  final double sensitivity; // paramètre de filtrage (0..1)
  final int actualDataDurationSeconds; // durée réelle des données disponibles
  
  /// Fiabilité basée sur la durée effective vs durée demandée
  /// Vert si on a 100% de la durée demandée + minimum de points
  bool get isReliable {
    final requiredDuration = windowSeconds; // 100% de la durée demandée
    final hasEnoughDuration = actualDataDurationSeconds >= requiredDuration;
    final hasMinimumPoints = supportPoints >= 8;
    return hasEnoughDuration && hasMinimumPoints;
  }
  
  /// Pourcentage de la durée demandée effectivement collectée
  double get dataCompletenessPercent {
    if (windowSeconds == 0) return 0;
    return (actualDataDurationSeconds / windowSeconds * 100).clamp(0, 100);
  }
}

/// Analyse la tendance (rotation progressive) vs irrégularité (oscillation) du vent.
/// Paramètres de filtrage :
/// - windowSeconds: durée de la fenêtre d'analyse (période d'étude complète)
/// - analysisWindowSeconds: durée pour calculer la variation moyenne (ex: 20min = 1200s)
/// - minSlopeDegPerMin: pente minimale (après normalisation par sensibilité) pour considérer 'rotation'
/// - oscillationThresholdDeg: amplitude max acceptable pour dire qu'on a une rotation relativement régulière
class WindTrendAnalyzer {
  WindTrendAnalyzer({
    required this.windowSeconds,
    this.analysisWindowSeconds, // si null, utilise windowSeconds
    required this.minSlopeDegPerMinBase,
    required this.oscillationThresholdDegBase,
    required this.sensitivity, // 0 = peu sensible (nécessite forte pente), 1 = très sensible
  }) : assert(sensitivity >= 0 && sensitivity <= 1);

  final int windowSeconds;
  final int? analysisWindowSeconds; // fenêtre pour calcul tendance (si différente de windowSeconds)
  final double minSlopeDegPerMinBase;
  final double oscillationThresholdDegBase;
  final double sensitivity; // ajuste dynamiquement les seuils

  final Queue<_TimedDir> _samples = Queue();
  
  /// Crée une nouvelle instance avec des paramètres mis à jour mais en préservant l'historique
  WindTrendAnalyzer updateParameters({
    int? analysisWindowSeconds,
    double? sensitivity,
  }) {
    final newAnalyzer = WindTrendAnalyzer(
      windowSeconds: windowSeconds,
      analysisWindowSeconds: analysisWindowSeconds ?? this.analysisWindowSeconds,
      minSlopeDegPerMinBase: minSlopeDegPerMinBase,
      oscillationThresholdDegBase: oscillationThresholdDegBase,
      sensitivity: sensitivity ?? this.sensitivity,
    );
    
    // IMPORTANT : Copier l'historique existant vers la nouvelle instance
    newAnalyzer._samples.addAll(_samples);
    
    print('🔄 Paramètres analyseur mis à jour: fenêtre=${newAnalyzer.effectiveAnalysisWindow}s, sensibilité=${newAnalyzer.sensitivity}, historique=${_samples.length} pts');
    
    return newAnalyzer;
  }
  
  /// Durée effective pour le calcul de la tendance
  int get effectiveAnalysisWindow => analysisWindowSeconds ?? windowSeconds;

  /// Calcule la durée réelle des données disponibles (en secondes)
  int _getActualDataDurationSeconds() {
    if (_samples.isEmpty) return 0;
    if (_samples.length == 1) return 0;
    return _samples.last.time.difference(_samples.first.time).inSeconds;
  }

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
        windowSeconds: effectiveAnalysisWindow,
        sensitivity: sensitivity,
        actualDataDurationSeconds: _getActualDataDurationSeconds(),
      );
    }
    
    // Sélectionner les données pour l'analyse de tendance
    final analysisSamples = _getAnalysisSamples(now);
    if (analysisSamples.length < 5) {
      return WindTrendSnapshot(
        trend: WindTrendDirection.neutral,
        linearSlopeDegPerMin: 0,
        supportPoints: analysisSamples.length,
        windowSeconds: effectiveAnalysisWindow,
        sensitivity: sensitivity,
        actualDataDurationSeconds: _getActualDataDurationSeconds(),
      );
    }
    
    // Régression linéaire simple sur (t, dir). Normaliser t en minutes relative.
    final firstT = analysisSamples.first.time;
    final xs = <double>[];
    final ys = <double>[];
    for (final s in analysisSamples) {
      xs.add(s.time.difference(firstT).inMilliseconds / 60000.0); // minutes
      ys.add(s.dir);
    }
    final adjustedYs = _unwrapAngles(analysisSamples.map((s) => s.dir).toList());
    final slope = _linearSlope(xs, adjustedYs); // deg/min
    final minSlope = _adjustMinSlope();
    // CORRECTION : Calculer oscillation comme résidus par rapport à la régression
    final oscillation = _oscillationAroundTrend(xs, adjustedYs, slope);
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
    // Debug pour diagnostiquer la convergence
    if (analysisSamples.length > 20 && analysisSamples.length % 10 == 0) {
      final duration = analysisSamples.last.time.difference(analysisSamples.first.time).inSeconds;
      print('📊 Trend Analysis: ${analysisSamples.length} pts sur ${duration}s, slope=${slope.toStringAsFixed(2)}°/min, oscillation=${oscillation.toStringAsFixed(1)}°');
    }

    return WindTrendSnapshot(
      trend: trend,
      linearSlopeDegPerMin: slope,
      supportPoints: analysisSamples.length,
      windowSeconds: effectiveAnalysisWindow,
      sensitivity: sensitivity,
      actualDataDurationSeconds: _getActualDataDurationSeconds(),
    );
  }

  /// Sélectionne les échantillons pour l'analyse de tendance selon la fenêtre configurée
  List<_TimedDir> _getAnalysisSamples(DateTime now) {
    final analysisCutoff = now.subtract(Duration(seconds: effectiveAnalysisWindow));
    
    // Si on a moins de données que la fenêtre d'analyse demandée, utiliser ce qu'on a
    final availableSamples = _samples.where((sample) => 
      sample.time.isAfter(analysisCutoff) || sample.time.isAtSameMomentAs(analysisCutoff)
    ).toList();
    
    // Si pas assez de données dans la fenêtre d'analyse, prendre les plus récentes disponibles
    if (availableSamples.length < 5 && _samples.length >= 5) {
      return _samples.toList(); // Utiliser toutes les données disponibles
    }
    
    return availableSamples;
  }

  double _linearSlope(List<double> xs, List<double> ys) {
    final n = xs.length;
    if (n < 2) return 0;
    
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

  /// Déroule les angles pour éviter les discontinuités 0°/360°
  /// Ex: [359, 1, 3] → [359, 361, 363] pour une régression cohérente
  List<double> _unwrapAngles(List<double> angles) {
    if (angles.length < 2) return List.from(angles);
    
    final result = <double>[angles.first];
    
    for (int i = 1; i < angles.length; i++) {
      double currentAngle = angles[i];
      double previousUnwrapped = result.last;
      
      // Calculer la différence en tenant compte de la circularité
      double delta = currentAngle - (previousUnwrapped % 360);
      
      // Normaliser delta dans [-180, 180]
      while (delta > 180) {
        delta -= 360;
      }
      while (delta < -180) {
        delta += 360;
      }
      
      // Ajouter le delta à l'angle précédent déroulé
      result.add(previousUnwrapped + delta);
    }
    
    return result;
  }



  /// Calcule l'oscillation comme l'écart-type des résidus par rapport à la régression
  /// Cette méthode est stable dans le temps et insensible à la dérive
  double _oscillationAroundTrend(List<double> xs, List<double> ys, double slope) {
    if (xs.length != ys.length || xs.length < 2) return 0;
    
    final n = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;
    
    // Calculer les résidus par rapport à la ligne de régression
    double sumSquaredResiduals = 0;
    for (int i = 0; i < n; i++) {
      final predictedY = meanY + slope * (xs[i] - meanX);
      final residual = ys[i] - predictedY;
      sumSquaredResiduals += residual * residual;
    }
    
    // Écart-type des résidus
    final residualVariance = sumSquaredResiduals / (n - 1);
    final residualStdDev = math.sqrt(residualVariance);
    
    // Convertir en amplitude approximative (±2 écart-types = 95% des données)
    return residualStdDev * 4.0;
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
