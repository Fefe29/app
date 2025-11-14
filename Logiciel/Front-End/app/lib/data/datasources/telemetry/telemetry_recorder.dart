/// Enregistreur de télémétrie - Gère le cycle de vie d'une session d'enregistrement.
/// Responsabilités:
/// - Démarrer/arrêter l'enregistrement
/// - Bufferer les données pour éviter les écritures trop fréquentes
/// - Gérer les erreurs et les reconnexions
/// - Notifier du progrès via des callbacks
/// 
/// Exemple d'utilisation:
/// ```dart
/// final recorder = TelemetryRecorder(storage, telemetryBus);
/// 
/// // Démarrer l'enregistrement
/// await recorder.startRecording('session_2025_11_14_regatta');
/// 
/// // Enregistrement automatique du bus...
/// 
/// // Arrêter
/// final metadata = await recorder.stopRecording();
/// print('Session enregistrée: ${metadata.snapshotCount} points');
/// ```

import 'dart:async';
import 'package:kornog/data/datasources/telemetry/telemetry_bus.dart';
import 'package:kornog/domain/entities/telemetry.dart';
import 'telemetry_storage.dart';

/// Callback pour notifier du progrès
typedef OnProgressCallback = void Function(int snapshotCount, Duration elapsed);

/// État actuel de l'enregistreur
enum RecorderState { idle, recording, paused, error }

class RecorderError {
  const RecorderError({
    required this.message,
    required this.timestamp,
    this.exception,
    this.stackTrace,
  });

  final String message;
  final DateTime timestamp;
  final dynamic exception;
  final StackTrace? stackTrace;

  @override
  String toString() => 'RecorderError($message at $timestamp)';
}

class TelemetryRecorder {
  final TelemetryStorage storage;
  final TelemetryBus telemetryBus;

  /// Callback appelé à chaque nouveau snapshot enregistré
  OnProgressCallback? onProgress;

  /// Callback appelé en cas d'erreur
  Function(RecorderError error)? onError;

  TelemetryRecorder({
    required this.storage,
    required this.telemetryBus,
    this.onProgress,
    this.onError,
  });

  // État interne
  RecorderState _state = RecorderState.idle;
  StreamSubscription<TelemetrySnapshot>? _subscription;
  String? _currentSessionId;
  DateTime? _recordingStartTime;
  int _snapshotCount = 0;
  final List<RecorderError> _errors = [];

  /// État actuel
  RecorderState get state => _state;

  /// Session actuelle (null si pas en enregistrement)
  String? get currentSessionId => _currentSessionId;

  /// Nombre de snapshots enregistrés
  int get snapshotCount => _snapshotCount;

  /// Durée de l'enregistrement en cours
  Duration get elapsedTime {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Historique des erreurs
  List<RecorderError> get errors => List.unmodifiable(_errors);

  /// Démarrer l'enregistrement d'une nouvelle session
  ///
  /// Lance une exception si une session est déjà en cours d'enregistrement.
  /// Crée une nouvelle session et commence à sauvegarder les snapshots du bus.
  Future<void> startRecording(String sessionId) async {
    if (_state != RecorderState.idle) {
      throw Exception('Enregistrement déjà en cours (état: $_state). '
          'Appelez stopRecording() d\'abord.');
    }

    // Vérifier que la session n'existe pas déjà
    if (await storage.sessionExists(sessionId)) {
      throw Exception('Session $sessionId existe déjà');
    }

    _state = RecorderState.recording;
    _currentSessionId = sessionId;
    _recordingStartTime = DateTime.now();
    _snapshotCount = 0;
    _errors.clear();

    // Controller pour accumuler les snapshots
    final controller = StreamController<TelemetrySnapshot>.broadcast();

    // S'abonner au bus et ajouter les snapshots au contrôleur
    _subscription = telemetryBus.snapshots().listen(
      (snapshot) {
        controller.add(snapshot);
        _snapshotCount++;

        // Notifier du progrès
        onProgress?.call(_snapshotCount, elapsedTime);
      },
      onError: (error, stackTrace) {
        _addError(
          'Erreur réception du bus: $error',
          error,
          stackTrace,
        );
        controller.addError(error, stackTrace);
      },
      onDone: () {
        controller.close();
      },
    );

    // Sauvegarder les snapshots dans le stockage
    try {
      await storage.saveSession(sessionId, controller.stream);
    } catch (e, st) {
      _state = RecorderState.error;
      _addError('Erreur sauvegarde session: $e', e, st);
      await stopRecording();
      rethrow;
    }
  }

  /// Arrêter l'enregistrement en cours
  ///
  /// Retourne les métadonnées de la session enregistrée.
  /// Lance une exception s'il n'y a pas d'enregistrement en cours.
  Future<SessionMetadata> stopRecording() async {
    if (_state != RecorderState.recording && _state != RecorderState.error) {
      throw Exception('Aucun enregistrement en cours (état: $_state)');
    }

    final sessionId = _currentSessionId;
    if (sessionId == null) {
      throw Exception('Pas de session active');
    }

    // Arrêter la souscription au bus
    await _subscription?.cancel();
    _subscription = null;

    // Attendre que la sauvegarde soit terminée
    _state = RecorderState.idle;

    // Récupérer les métadonnées
    final metadata = await storage.getSessionMetadata(sessionId);

    // Réinitialiser l'état
    _currentSessionId = null;
    _recordingStartTime = null;

    return metadata;
  }

  /// Mettre l'enregistrement en pause
  ///
  /// Les snapshots ne seront plus enregistrés jusqu'à la reprise.
  void pauseRecording() {
    if (_state != RecorderState.recording) {
      throw Exception('Aucun enregistrement en cours');
    }

    _subscription?.pause();
    _state = RecorderState.paused;
  }

  /// Reprendre l'enregistrement après une pause
  void resumeRecording() {
    if (_state != RecorderState.paused) {
      throw Exception('Pas d\'enregistrement en pause');
    }

    _subscription?.resume();
    _state = RecorderState.recording;
  }

  /// Obtenir les stats de l'enregistrement en cours
  Future<SessionStats> getCurrentStats() async {
    final sessionId = _currentSessionId;
    if (sessionId == null) {
      throw Exception('Aucun enregistrement en cours');
    }

    return storage.getSessionStats(sessionId);
  }

  /// Vider les erreurs enregistrées
  void clearErrors() {
    _errors.clear();
  }

  // ============================================================================
  // Helpers privés
  // ============================================================================

  void _addError(String message, dynamic exception, StackTrace? stackTrace) {
    final error = RecorderError(
      message: message,
      timestamp: DateTime.now(),
      exception: exception,
      stackTrace: stackTrace,
    );

    _errors.add(error);

    // Notifier via callback
    onError?.call(error);

    // Log pour debug
    print('🔴 TelemetryRecorder Error: $message');
    if (exception != null) {
      print('   Exception: $exception');
      if (stackTrace != null) {
        print('   StackTrace: $stackTrace');
      }
    }
  }

  /// Nettoyer les ressources
  Future<void> dispose() async {
    if (_state == RecorderState.recording) {
      try {
        await stopRecording();
      } catch (e) {
        print('⚠️ Erreur lors du cleanup: $e');
      }
    }
    await _subscription?.cancel();
  }
}
