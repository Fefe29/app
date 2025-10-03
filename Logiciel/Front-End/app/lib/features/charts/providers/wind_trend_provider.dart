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

class _WindTrendAnalyzerNotifier extends Notifier<WindTrendAnalyzer?> {
  @override
  WindTrendAnalyzer? build() {
    // Écouter les changements de paramètres
    ref.listen(windTrendSensitivityProvider, (previous, next) {
      _updateParameters();
    });
    
    ref.listen(windAnalysisWindowProvider, (previous, next) {
      _updateParameters();
    });
    
    // Créer l'analyseur initial
    return _createInitialAnalyzer();
  }
  
  WindTrendAnalyzer _createInitialAnalyzer() {
    final sens = ref.read(windTrendSensitivityProvider);
    final analysisWindow = ref.read(windAnalysisWindowProvider);
    
    return WindTrendAnalyzer(
      windowSeconds: 3600, // Garder 1h de données max
      analysisWindowSeconds: analysisWindow,
      minSlopeDegPerMinBase: 4,
      oscillationThresholdDegBase: 18,
      sensitivity: sens,
    );
  }
  
  void _updateParameters() {
    final current = state;
    if (current == null) return;
    
    final sens = ref.read(windTrendSensitivityProvider);
    final analysisWindow = ref.read(windAnalysisWindowProvider);
    
    // Mettre à jour avec préservation de l'historique
    state = current.updateParameters(
      analysisWindowSeconds: analysisWindow,
      sensitivity: sens,
    );
  }
}

final _windTrendAnalyzerProvider = NotifierProvider<_WindTrendAnalyzerNotifier, WindTrendAnalyzer?>(_WindTrendAnalyzerNotifier.new);

/// Fournit un snapshot recalculé à 1 Hz (car dépend du provider vent qui se met à jour).
final windTrendSnapshotProvider = Provider<WindTrendSnapshot>((ref) {
  final analyzer = ref.watch(_windTrendAnalyzerProvider);
  final windSample = ref.watch(windSampleProvider);
  
  // Si l'analyseur n'est pas encore initialisé, retourner un snapshot neutre
  if (analyzer == null) {
    return WindTrendSnapshot(
      trend: WindTrendDirection.neutral,
      linearSlopeDegPerMin: 0,
      supportPoints: 0,
      windowSeconds: ref.read(windAnalysisWindowProvider),
      sensitivity: ref.read(windTrendSensitivityProvider),
      actualDataDurationSeconds: 0,
    );
  }
  
  return analyzer.ingest(windSample);
});
