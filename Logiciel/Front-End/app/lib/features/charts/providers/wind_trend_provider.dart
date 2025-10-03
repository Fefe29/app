/// Wind Trend Provider
/// ---------------------------------------------
/// Aggregates recent wind measurements for trend visualization (lifting/header analysis etc.).
/// See ARCHITECTURE_DOCS.md (section: wind_trend_provider.dart) for detailed documentation.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/wind_trend_analyzer.dart';
import 'package:kornog/common/providers/app_providers.dart';

class _WindTrendSensitivity extends Notifier<double> {
  @override
  double build() => 0.5; // valeur initiale
  void set(double v) => state = v.clamp(0.0, 1.0);
}

class _WindAnalysisWindow extends Notifier<int> {
  @override
  int build() => 1200; // 20 minutes par défaut (en secondes)
  void setMinutes(int minutes) => state = (minutes * 60).clamp(60, 3600); // 1min à 1h
  void setSeconds(int seconds) => state = seconds.clamp(60, 3600);
}

final windTrendSensitivityProvider = NotifierProvider<_WindTrendSensitivity, double>(_WindTrendSensitivity.new);
final windAnalysisWindowProvider = NotifierProvider<_WindAnalysisWindow, int>(_WindAnalysisWindow.new);

final _windTrendAnalyzerProvider = Provider<WindTrendAnalyzer>((ref) {
  final sens = ref.watch(windTrendSensitivityProvider);
  final analysisWindow = ref.watch(windAnalysisWindowProvider);
  
  return WindTrendAnalyzer(
    windowSeconds: 3600, // Garder 1h de données max
    analysisWindowSeconds: analysisWindow, // Fenêtre d'analyse configurable
    minSlopeDegPerMinBase: 4,
    oscillationThresholdDegBase: 18,
    sensitivity: sens,
  );
});

/// Fournit un snapshot recalculé à 1 Hz (car dépend du provider vent qui se met à jour).
final windTrendSnapshotProvider = Provider<WindTrendSnapshot>((ref) {
  final analyzer = ref.watch(_windTrendAnalyzerProvider);
  final windSample = ref.watch(windSampleProvider);
  return analyzer.ingest(windSample);
});
