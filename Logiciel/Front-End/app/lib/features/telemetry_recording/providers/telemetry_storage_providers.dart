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
import 'package:kornog/common/providers/app_providers.dart'
    show telemetryBusProvider;

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

/// Provider pour obtenir le répertoire de stockage des sessions
/// 
/// Sur mobile : chemin de document de l'application
/// Sur desktop : répertoire home/.kornog/telemetry
Future<Directory> _getStorageDirectory() async {
  final baseDir = await getApplicationDocumentsDirectory();
  final sessionDir = Directory('${baseDir.path}/.kornog/telemetry');
  await sessionDir.create(recursive: true);
  return sessionDir;
}

final telemetryStorageDirectoryProvider = FutureProvider<Directory>((ref) async {
  return _getStorageDirectory();
});

/// Provider pour l'instance TelemetryStorage
/// 
/// Utilise JsonTelemetryStorage par défaut.
/// À remplacer pour changer d'implémentation (Parquet, SQLite, etc.)
final telemetryStorageProvider = FutureProvider<TelemetryStorage>((ref) async {
  final storageDir = await ref.watch(telemetryStorageDirectoryProvider.future);
  return JsonTelemetryStorage(storageDir: storageDir);
});

// ============================================================================
// Providers pour l'enregistrement
// ============================================================================

/// Provider pour l'instance TelemetryRecorder
final telemetryRecorderProvider =
    Provider<TelemetryRecorder>((ref) {
  final storage = ref.watch(telemetryStorageProvider).value;
  final bus = ref.watch(telemetryBusProvider);

  if (storage == null) {
    throw Exception('Storage non disponible');
  }

  return TelemetryRecorder(
    storage: storage,
    telemetryBus: bus,
  );
});

// ============================================================================
// Recordingnotifier pour l'enregistrement
// ============================================================================

/// Notifier pour l'état de l'enregistrement en cours
class RecordingStateNotifier extends Notifier<RecorderState> {
  @override
  RecorderState build() => RecorderState.idle;

  RecorderState get current => state;

  /// Démarrer un nouvel enregistrement
  Future<void> startRecording(String sessionId) async {
    final recorder = ref.read(telemetryRecorderProvider);

    try {
      state = RecorderState.recording;
      await recorder.startRecording(sessionId);
    } catch (e) {
      state = RecorderState.error;
      rethrow;
    }
  }

  /// Arrêter l'enregistrement en cours
  Future<SessionMetadata> stopRecording() async {
    final recorder = ref.read(telemetryRecorderProvider);

    try {
      final metadata = await recorder.stopRecording();
      state = RecorderState.idle;
      return metadata;
    } catch (e) {
      state = RecorderState.error;
      rethrow;
    }
  }

  /// Mettre en pause
  void pauseRecording() {
    final recorder = ref.read(telemetryRecorderProvider);
    recorder.pauseRecording();
    state = RecorderState.paused;
  }

  /// Reprendre
  void resumeRecording() {
    final recorder = ref.read(telemetryRecorderProvider);
    recorder.resumeRecording();
    state = RecorderState.recording;
  }
}

/// Provider pour l'état de l'enregistrement en cours
final recordingStateProvider = NotifierProvider<
    RecordingStateNotifier,
    RecorderState>(() => RecordingStateNotifier());

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

/// Provider pour charger une session complète
final sessionDataProvider =
    FutureProvider.family<List<TelemetrySnapshot>, String>((ref, sessionId) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.loadSession(sessionId);
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
