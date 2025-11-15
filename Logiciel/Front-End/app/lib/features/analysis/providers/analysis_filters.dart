/// Analysis filters provider definitions.
/// See ARCHITECTURE_DOCS.md (section: analysis_filters.dart).
// lib/features/analysis/analysis_filters.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';
import 'package:kornog/features/analysis/domain/services/wind_history_service.dart';

@immutable
class AnalysisFilters {
  final bool twd;
  final bool tws;
  final bool twa;
  final bool boatSpeed;
  final bool polars;

  const AnalysisFilters({
    this.twd = true,
    this.tws = false, // Désactivé par défaut
    this.twa = true,
    this.boatSpeed = true,
    this.polars = true, // Polaires affichées par défaut
  });

  AnalysisFilters copyWith({
    bool? twd,
    bool? tws,
    bool? twa,
    bool? boatSpeed,
    bool? polars,
  }) {
    return AnalysisFilters(
      twd: twd ?? this.twd,
      tws: tws ?? this.tws,
      twa: twa ?? this.twa,
      boatSpeed: boatSpeed ?? this.boatSpeed,
      polars: polars ?? this.polars,
    );
  }
}

class AnalysisFiltersNotifier extends Notifier<AnalysisFilters> {
  @override
  AnalysisFilters build() => const AnalysisFilters();

  // setters rapides
  void set({
    bool? twd,
    bool? tws,
    bool? twa,
    bool? boatSpeed,
    bool? polars,
  }) {
    state = state.copyWith(
      twd: twd,
      tws: tws,
      twa: twa,
      boatSpeed: boatSpeed,
      polars: polars,
    );
  }

  // toggles pratiques
  void toggleTwd() => state = state.copyWith(twd: !state.twd);
  void toggleTws() => state = state.copyWith(tws: !state.tws);
  void toggleTwa() => state = state.copyWith(twa: !state.twa);
  void toggleBoatSpeed() => state = state.copyWith(boatSpeed: !state.boatSpeed);
  void togglePolars() => state = state.copyWith(polars: !state.polars);
}

final analysisFiltersProvider =
    NotifierProvider<AnalysisFiltersNotifier, AnalysisFilters>(
  AnalysisFiltersNotifier.new,
);

/// Notifier pour la session historique sélectionnée
class SelectedSessionNotifier extends Notifier<String?> {
  @override
  String? build() {
    print('🔧 [SelectedSessionNotifier.build] Initialisation - state: null');
    return null;  // null = real-time data
  }

  void selectSession(String sessionId) {
    print('═══════════════════════════════════════════════════════════');
    print('� [SelectedSessionNotifier.selectSession] NOUVELLE SÉLECTION');
    print('   sessionId: $sessionId');
    print('   ancien state: $state');
    print('═══════════════════════════════════════════════════════════');
    state = sessionId;
    print('✅ [SelectedSessionNotifier] State modifié: $state');
  }

  void clearSelection() {
    print('═══════════════════════════════════════════════════════════');
    print('🔄 [SelectedSessionNotifier.clearSelection] RETOUR AU TEMPS RÉEL');
    print('   ancien state: $state');
    print('═══════════════════════════════════════════════════════════');
    state = null;
    print('✅ [SelectedSessionNotifier] State modifié: null (temps réel)');
  }
}

/// Provider pour la session historique sélectionnée
/// Si null = affiche données temps réel
/// Si non-null = affiche données de la session
final selectedSessionProvider = NotifierProvider<SelectedSessionNotifier, String?>(
  SelectedSessionNotifier.new,
);

/// Provider pour charger et transformer les données d'une session
/// Paramètres: (sessionId, metricKey)
/// Exemple: sessionHistoryDataProvider(('session_123', 'wind.twd'))
final sessionHistoryDataProvider =
    FutureProvider.family<List<HistoryDataPoint>, (String, String)>(
  (ref, params) async {
    final (sessionId, metricKey) = params;
    
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('� [sessionHistoryDataProvider] DÉMARRAGE');
    print('   sessionId: $sessionId');
    print('   metricKey: $metricKey');
    print('═══════════════════════════════════════════════════════════');
    
    try {
      // Charger les snapshots de la session
      print('📦 [sessionHistoryDataProvider] Appel sessionDataProvider($sessionId)...');
      final snapshots = await ref.watch(sessionDataProvider(sessionId).future);
      print('✅ [sessionHistoryDataProvider] Chargé ${snapshots.length} snapshots');
      
      if (snapshots.isEmpty) {
        print('⚠️ [sessionHistoryDataProvider] ATTENTION: Aucun snapshot!');
        return [];
      }
      
      // Afficher le premier snapshot pour diagnostiquer
      print('📋 [sessionHistoryDataProvider] Premier snapshot:');
      print('   ts: ${snapshots.first.ts}');
      print('   metriques clés: ${snapshots.first.metrics.keys.toList()}');
      
      // Transformer en HistoryDataPoint
      final dataPoints = <HistoryDataPoint>[];
      int found = 0;
      int notFound = 0;
      
      for (int i = 0; i < snapshots.length; i++) {
        final snapshot = snapshots[i];
        final measurement = snapshot.metrics[metricKey];
        
        if (measurement != null) {
          dataPoints.add(HistoryDataPoint(
            timestamp: snapshot.ts,
            value: measurement.value,
          ));
          found++;
        } else {
          notFound++;
        }
      }
      
      print('🔍 [sessionHistoryDataProvider] Recherche $metricKey:');
      print('   ✅ Trouvés: $found');
      print('   ❌ Non trouvés: $notFound');
      print('   📊 Total HistoryDataPoint créés: ${dataPoints.length}');
      
      if (dataPoints.isEmpty) {
        print('⚠️ [sessionHistoryDataProvider] ATTENTION: Aucun HistoryDataPoint! Vérifiez la clé $metricKey');
      }
      
      print('═══════════════════════════════════════════════════════════');
      print('✅ [sessionHistoryDataProvider] SUCCÈS - Retourne ${dataPoints.length} points');
      print('═══════════════════════════════════════════════════════════');
      print('');
      
      return dataPoints;
    } catch (e, st) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ [sessionHistoryDataProvider] ERREUR');
      print('   Exception: $e');
      print('   StackTrace: $st');
      print('═══════════════════════════════════════════════════════════');
      print('');
      rethrow;
    }
  },
);
