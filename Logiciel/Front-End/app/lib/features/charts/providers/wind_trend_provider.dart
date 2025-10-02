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

final windTrendSensitivityProvider = NotifierProvider<_WindTrendSensitivity, double>(_WindTrendSensitivity.new);

final _windTrendAnalyzerProvider = Provider<WindTrendAnalyzer>((ref) {
  final sens = ref.watch(windTrendSensitivityProvider);
  return WindTrendAnalyzer(
    windowSeconds: 90,
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
