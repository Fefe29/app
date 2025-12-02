/// Providers Riverpod pour la couche de persistance télémétrique.
/// 
/// Fournit l'injection de dépendances pour :
/// - TelemetryStorage (interface abstraite)
/// - TelemetryRecorder
/// - Listing des sessions
/// - Stats des sessions
///
/// Exemple d'utilisation dans les widgets:
/// ```dart
/// class RecordingButton extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final recorder = ref.watch(telemetryRecorderProvider);
///     return ElevatedButton(
///       onPressed: () async {
///         await recorder.startRecording('session_${DateTime.now().millisecondsSinceEpoch}');
///       },
///       child: Text('Enregistrer'),
///     );
///   }
/// }
/// ```

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_storage.dart';
import 'package:kornog/data/datasources/telemetry/json_telemetry_storage.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_recorder.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_bus.dart';
import 'package:kornog/domain/entities/telemetry.dart';
import 'package:kornog/features/telemetry_recording/models/recording_options.dart';
import 'package:kornog/common/providers/app_providers.dart'
    show telemetryBusProvider;
import 'package:kornog/common/kornog_data_directory.dart'
    show getTelemetryDataDirectory;

// ============================================================================
// Re-export des entités pour facilité d'accès
// ============================================================================

export 'package:kornog/data/datasources/telemetry/telemetry_storage.dart'
    show SessionMetadata, SessionStats, SessionLoadFilter, TelemetrySnapshot;
export 'package:kornog/data/datasources/telemetry/telemetry_recorder.dart'
    show RecorderState, TelemetryRecorder;

// ============================================================================
// Providers fondamentaux
// ============================================================================

/// Provider pour obtenir le répertoire de stockage des sessions télémétrique
/// 
/// Utilise getTelemetryDataDirectory() pour accéder à KornogData/telemetry
final telemetryStorageDirectoryProvider = FutureProvider<Directory>((ref) async {
  print('🔧 [telemetryStorageDirectoryProvider] Obtention du répertoire de télémétrie...');
  final telemetryDir = await getTelemetryDataDirectory();
  print('✅ [telemetryStorageDirectoryProvider] Répertoire: ${telemetryDir.path}');
  return telemetryDir;
});

/// Provider pour l'instance TelemetryStorage
/// 
/// Utilise JsonTelemetryStorage par défaut.
/// À remplacer pour changer d'implémentation (Parquet, SQLite, etc.)
final telemetryStorageProvider = FutureProvider<TelemetryStorage>((ref) async {
  print('🔧 [telemetryStorageProvider] Initialisation du stockage...');
  final storageDir = await ref.watch(telemetryStorageDirectoryProvider.future);
  print('📂 [telemetryStorageProvider] Répertoire stockage: ${storageDir.path}');
  final storage = JsonTelemetryStorage(storageDir: storageDir);
  print('✅ [telemetryStorageProvider] Stockage JSON initialisé');
  return storage;
});

// ============================================================================
// Providers pour l'enregistrement
// ============================================================================

/// Notifier pour conserver une instance unique de TelemetryRecorder
class TelemetryRecorderNotifier extends Notifier<TelemetryRecorder?> {
  @override
  TelemetryRecorder? build() {
    print('🔧 [TelemetryRecorderNotifier] build() appelé - lancement init async');
    _initializeAsync();
    return null; // Sera remplacé par _initializeAsync
  }

  Future<void> _initializeAsync() async {
    try {
      print('🔧 [TelemetryRecorderNotifier] Attente storage...');
      final storage = await ref.watch(telemetryStorageProvider.future);
      final bus = ref.watch(telemetryBusProvider);

      if (storage == null) {
        throw Exception('Storage non disponible');
      }

      final recorder = TelemetryRecorder(
        storage: storage,
        telemetryBus: bus,
      );
      state = recorder;
      print('✅ [TelemetryRecorderNotifier] Recorder initialisé: ${recorder.hashCode}');
    } catch (e, st) {
      print('❌ [TelemetryRecorderNotifier] Erreur: $e');
      print('   StackTrace: $st');
    }
  }
}

/// Provider pour l'instance TelemetryRecorder - PERSISTE pendant toute l'app
/// Important: Retourne la MÊME instance à chaque accès pour que currentSessionId
/// soit cohérent entre les appels
final telemetryRecorderProvider =
    NotifierProvider<TelemetryRecorderNotifier, TelemetryRecorder?>(
  () => TelemetryRecorderNotifier(),
);

// ============================================================================
// Recordingnotifier pour l'enregistrement
// ============================================================================

/// Notifier pour l'état de l'enregistrement en cours
class RecordingStateNotifier extends Notifier<RecorderState> {
  @override
  RecorderState build() {
    print('🔧 [RecordingStateNotifier] Initialisation: IDLE');
    return RecorderState.idle;
  }

  RecorderState get current => state;

  /// Démarrer un nouvel enregistrement
  Future<void> startRecording(String sessionId, [RecordingOptions? options]) async {
    print('📱 [RecordingStateNotifier] startRecording($sessionId)');
    var recorder = ref.read(telemetryRecorderProvider);
    
    print('📝 [RecordingStateNotifier] Recorder obtenu: ${recorder != null ? "OK (${recorder.hashCode})" : "NULL"}');

    // Si recorder est null, attendre son initialisation
    if (recorder == null) {
      print('⏳ [RecordingStateNotifier] Recorder non initialisé, attente...');
      // Déclencher l'initialisation en lisant la storage
      await ref.read(telemetryStorageProvider.future);
      // Attendre un peu que la NotifierProvider finisse son init
      await Future.delayed(const Duration(milliseconds: 500));
      // Relire le recorder
      recorder = ref.read(telemetryRecorderProvider);
      print('📝 [RecordingStateNotifier] Recorder re-obtenu: ${recorder != null ? "OK (${recorder.hashCode})" : "STILL NULL"}');
    }

    if (recorder == null) {
      throw Exception('Recorder non disponible après init');
    }

    try {
      print('� [RecordingStateNotifier] Appel recorder.startRecording()...');
      await recorder.startRecording(sessionId, options);
      print('✅ [RecordingStateNotifier] recorder.startRecording() terminé');
      
      // PUIS on change l'état APRÈS que le recorder soit vraiment en enregistrement
      print('🔴 [RecordingStateNotifier] État → RECORDING');
      state = RecorderState.recording;
      
      print('✅ [RecordingStateNotifier] startRecording terminé (état changé)');
    } catch (e, st) {
      print('❌ [RecordingStateNotifier] Erreur startRecording: $e');
      print('   StackTrace: $st');
      state = RecorderState.error;
      rethrow;
    }
  }

  /// Arrêter l'enregistrement en cours
  Future<SessionMetadata> stopRecording() async {
    print('📱 [RecordingStateNotifier] stopRecording()');
    final recorder = ref.read(telemetryRecorderProvider);

    if (recorder == null) {
      throw Exception('Recorder non disponible');
    }

    try {
      print('⏹️ [RecordingStateNotifier] Appel recorder.stopRecording()...');
      final metadata = await recorder.stopRecording();
      print('✅ [RecordingStateNotifier] stopRecording terminé');
      print('   - SessionId: ${metadata.sessionId}');
      print('   - Snapshots: ${metadata.snapshotCount}');
      print('   - Taille: ${metadata.sizeBytes} bytes');
      state = RecorderState.idle;
      print('⚪ [RecordingStateNotifier] État → IDLE');
      return metadata;
    } catch (e, st) {
      print('❌ [RecordingStateNotifier] Erreur stopRecording: $e');
      print('   StackTrace: $st');
      state = RecorderState.error;
      rethrow;
    }
  }

  /// Mettre en pause
  void pauseRecording() {
    print('📱 [RecordingStateNotifier] pauseRecording() - TODO: fix async');
    // TODO: Faire async pour accéder au FutureProvider
  }

  /// Reprendre
  void resumeRecording() {
    print('📱 [RecordingStateNotifier] resumeRecording() - TODO: fix async');
    // TODO: Faire async pour accéder au FutureProvider
  }
}

/// Provider pour l'état de l'enregistrement en cours
final recordingStateProvider = NotifierProvider<
    RecordingStateNotifier,
    RecorderState>(() => RecordingStateNotifier());

// ============================================================================
// Provider pour l'ID de la session en cours d'enregistrement
// ============================================================================

/// Provider pour obtenir les options d'enregistrement actuelles
final currentRecordingOptionsProvider = Provider<RecordingOptions?>((ref) {
  final recorder = ref.watch(telemetryRecorderProvider);
  final state = ref.watch(recordingStateProvider);
  
  // Retourner les options uniquement si en enregistrement ET recorder existe
  if (recorder != null && state == RecorderState.recording) {
    return recorder.recordingOptions;
  }
  
  return null;
});

/// Provider pour obtenir l'ID de la session en cours d'enregistrement
final currentRecordingSessionIdProvider = Provider<String?>((ref) {
  final recorder = ref.watch(telemetryRecorderProvider);
  final state = ref.watch(recordingStateProvider);
  
  print('🔍 [currentRecordingSessionIdProvider] État: $state, recorder: ${recorder != null ? 'ready' : 'null'}');
  
  // Retourner l'ID de session uniquement si en enregistrement ET recorder existe
  if (recorder != null && state == RecorderState.recording) {
    final sessionId = recorder.currentSessionId;
    print('🔍 [DEBUG] recorder.currentSessionId = $sessionId');
    print('🔍 [DEBUG] recorder = $recorder');
    print('🔍 [DEBUG] recorder.hashCode = ${recorder.hashCode}');
    print('🔍 [DEBUG] recorder.state = ${recorder.state}');
    print('✅ [currentRecordingSessionIdProvider] En enregistrement, retour: $sessionId');
    return sessionId;
  }
  
  print('⚪ [currentRecordingSessionIdProvider] Pas en enregistrement, retour null');
  return null;
});

// ============================================================================
// Providers pour la lecture des sessions
// ============================================================================

/// Provider pour lister toutes les sessions disponibles
final sessionsListProvider = FutureProvider<List<SessionMetadata>>((ref) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.listSessions();
});

/// Provider pour les métadonnées d'une session spécifique
final sessionMetadataProvider =
    FutureProvider.family<SessionMetadata, String>((ref, sessionId) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.getSessionMetadata(sessionId);
});

/// Provider pour les stats d'une session
final sessionStatsProvider =
    FutureProvider.family<SessionStats, String>((ref, sessionId) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.getSessionStats(sessionId);
});

/// Provider pour les stats en temps réel pendant l'enregistrement
/// S'auto-invalide toutes les secondes pour forcer le rafraîchissement
final currentSessionStatsProvider = FutureProvider<SessionStats?>((ref) async {
  final recordingState = ref.watch(recordingStateProvider);
  final recorder = ref.watch(telemetryRecorderProvider);
  final currentRecordingSessionId = ref.watch(currentRecordingSessionIdProvider);
  
  print('📊 [currentSessionStatsProvider] ======== BUILD ========');
  print('📊 [currentSessionStatsProvider] État enregistrement: $recordingState');
  print('📊 [currentSessionStatsProvider] Session ID: $currentRecordingSessionId');
  print('📊 [currentSessionStatsProvider] Recorder disponible: ${recorder != null}');
  
  // Si pas en enregistrement, retourner null
  if (recordingState != RecorderState.recording || currentRecordingSessionId == null || recorder == null) {
    print('⏸️ [currentSessionStatsProvider] Pas en enregistrement → retour NULL');
    return null;
  }
  
  print('✅ [currentSessionStatsProvider] En enregistrement → récupération stats');
  
  try {
    print('📈 [currentSessionStatsProvider] Appel recorder.getCurrentStats()...');
    final stats = await recorder.getCurrentStats();
    
    print('✅ [currentSessionStatsProvider] Stats REÇUES:');
    print('   - avgSpeed: ${stats.avgSpeed.toStringAsFixed(2)} kn');
    print('   - maxSpeed: ${stats.maxSpeed.toStringAsFixed(2)} kn');
    print('   - avgWindSpeed: ${stats.avgWindSpeed.toStringAsFixed(2)} kn');
    print('   - maxWindSpeed: ${stats.maxWindSpeed.toStringAsFixed(2)} kn');
    print('   - minWindSpeed: ${stats.minWindSpeed.toStringAsFixed(2)} kn');
    print('   - snapshotCount: ${stats.snapshotCount}');
    print('   - durationSeconds: ${stats.durationSeconds}');
    
    // Invalider ce provider après 1 seconde pour forcer le rafraîchissement
    print('⏳ [currentSessionStatsProvider] Programmation auto-invalidation 1s...');
    Future.delayed(const Duration(seconds: 1), () {
      print('🔄 [currentSessionStatsProvider] AUTO-INVALIDATION EXÉCUTÉE');
      ref.invalidateSelf();
    });
    
    print('📊 [currentSessionStatsProvider] RETOUR des stats à l\'UI');
    return stats;
  } catch (e, st) {
    print('❌ [currentSessionStatsProvider] ERREUR: $e');
    print('   StackTrace: $st');
    
    // Invalider quand même pour réessayer
    print('⏳ [currentSessionStatsProvider] Programmation auto-invalidation 1s (erreur)...');
    Future.delayed(const Duration(seconds: 1), () {
      print('🔄 [currentSessionStatsProvider] AUTO-INVALIDATION EXÉCUTÉE (erreur)');
      ref.invalidateSelf();
    });
    
    print('📊 [currentSessionStatsProvider] RETOUR NULL (erreur)');
    return null;
  }
});

/// Provider pour charger une session complète
final sessionDataProvider =
    FutureProvider.family<List<TelemetrySnapshot>, String>((ref, sessionId) async {
  print('📂 [sessionDataProvider] Chargement session: $sessionId');
  try {
    final storage = await ref.watch(telemetryStorageProvider.future);
    print('💾 [sessionDataProvider] Storage prêt, appel loadSession...');
    final snapshots = await storage.loadSession(sessionId);
    print('✅ [sessionDataProvider] Session chargée: ${snapshots.length} snapshots');
    return snapshots;
  } catch (e, st) {
    print('❌ [sessionDataProvider] ERREUR: $e');
    print('   Stack: $st');
    rethrow;
  }
});

/// Provider pour l'espace disque total utilisé
final totalStorageSizeProvider = FutureProvider<int>((ref) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.getTotalSizeBytes();
});

// ============================================================================
// Providers pour les actions de gestion
// ============================================================================

/// Provider pour les actions de gestion des sessions
final sessionManagementProvider = Provider((ref) {
  return SessionManagement(ref);
});

class SessionManagement {
  SessionManagement(this.ref);

  final Ref ref;

  /// Supprimer une session
  Future<void> deleteSession(String sessionId) async {
    final storage = await ref.read(telemetryStorageProvider.future);
    await storage.deleteSession(sessionId);
    // Invalider les caches
    ref.invalidate(sessionsListProvider);
    ref.invalidate(totalStorageSizeProvider);
  }

  /// Exporter une session
  Future<void> exportSession({
    required String sessionId,
    required String format,
    required String outputPath,
  }) async {
    final storage = await ref.read(telemetryStorageProvider.future);
    await storage.exportSession(
      sessionId: sessionId,
      format: format,
      outputPath: outputPath,
    );
  }

  /// Nettoyer les anciennes sessions
  Future<int> cleanupOldSessions({required int olderThanDays}) async {
    final storage = await ref.read(telemetryStorageProvider.future);
    final deleted = await storage.cleanupOldSessions(olderThanDays: olderThanDays);
    // Invalider les caches
    ref.invalidate(sessionsListProvider);
    ref.invalidate(totalStorageSizeProvider);
    return deleted;
  }
}

// ============================================================================
// Providers pour l'analyse des données
// ============================================================================

/// Provider pour filtrer et charger une session avec des critères
final filteredSessionProvider = FutureProvider.family<
    List<TelemetrySnapshot>,
    ({String sessionId, SessionLoadFilter filter})>((ref, params) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.loadSessionFiltered(params.sessionId, params.filter);
});

/// Provider pour extraire une métrique spécifique d'une session
final sessionMetricProvider = FutureProvider.family<
    List<({DateTime ts, double value})>,
    ({String sessionId, String metricKey})>((ref, params) async {
  final snapshots = await ref.watch(
    sessionDataProvider(params.sessionId).future,
  );

  return snapshots
      .map((TelemetrySnapshot snapshot) {
        final measurement = snapshot.metrics[params.metricKey];
        return (
          ts: snapshot.ts,
          value: measurement?.value ?? 0.0,
        );
      })
      .toList();
});
