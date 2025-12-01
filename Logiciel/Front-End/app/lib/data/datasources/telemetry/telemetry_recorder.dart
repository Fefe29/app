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
import 'package:kornog/features/telemetry_recording/models/recording_options.dart';
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
  Future<void>? _saveFuture; // 🆕 Track la Future de saveSession
  StreamController<TelemetrySnapshot>? _controller; // 🆕 Pour fermer le stream
  RecordingOptions _recordingOptions = const RecordingOptions(); // Options d'enregistrement

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
  /// 
  /// [options] définit quels types de données enregistrer (par défaut tout)
  Future<void> startRecording(String sessionId, [RecordingOptions? options]) async {
    print('🔴 [TelemetryRecorder] Démarrage enregistrement: $sessionId');
    print('   Options: ${options ?? const RecordingOptions()}');
    
    if (_state != RecorderState.idle) {
      print('❌ [TelemetryRecorder] État invalide: $_state');
      throw Exception('Enregistrement déjà en cours (état: $_state). '
          'Appelez stopRecording() d\'abord.');
    }

    // Vérifier que la session n'existe pas déjà
    if (await storage.sessionExists(sessionId)) {
      print('❌ [TelemetryRecorder] Session existe déjà: $sessionId');
      throw Exception('Session $sessionId existe déjà');
    }

    _recordingOptions = options ?? const RecordingOptions();
    _state = RecorderState.recording;
    _currentSessionId = sessionId;
    _recordingStartTime = DateTime.now();
    _snapshotCount = 0;
    _errors.clear();
    
    print('✅ [TelemetryRecorder] État: RECORDING');
    print('⏱️ [TelemetryRecorder] Heure début: $_recordingStartTime');

    // Controller pour accumuler les snapshots
    final controller = StreamController<TelemetrySnapshot>.broadcast();
    _controller = controller; // Stocker pour fermer dans stopRecording()

    // S'abonner au bus et ajouter les snapshots au contrôleur
    _subscription = telemetryBus.snapshots().listen(
      (snapshot) {
        // Filtrer les métriques selon les options d'enregistrement
        final filteredMetrics = <String, Measurement>{};
        for (final entry in snapshot.metrics.entries) {
          if (_recordingOptions.shouldRecord(entry.key)) {
            filteredMetrics[entry.key] = entry.value;
          }
        }

        // Si aucune métrique à enregistrer après filtrage, ignorer ce snapshot
        if (filteredMetrics.isEmpty) {
          print('🚫 [TelemetryRecorder] Snapshot ignoré (aucune métrique sélectionnée)');
          return;
        }

        // Créer un snapshot filtré et l'ajouter au controller
        final filteredSnapshot = TelemetrySnapshot(
          ts: snapshot.ts,
          metrics: filteredMetrics,
          tags: snapshot.tags,
        );
        controller.add(filteredSnapshot);
        _snapshotCount++;

        if (_snapshotCount % 50 == 0) {
          print('📡 [TelemetryRecorder] $_snapshotCount snapshots reçus');
        }

        // Notifier du progrès
        onProgress?.call(_snapshotCount, elapsedTime);
      },
      onError: (error, stackTrace) {
        print('❌ [TelemetryRecorder] Erreur du bus: $error');
        _addError(
          'Erreur réception du bus: $error',
          error,
          stackTrace,
        );
        controller.addError(error, stackTrace);
      },
      onDone: () {
        print('✅ [TelemetryRecorder] Stream du bus fermé');
        controller.close();
      },
    );

    // Sauvegarder les snapshots dans le stockage
    // NOTE: On NE attend PAS cette Future ici!
    // Elle sera attendue dans stopRecording() après fermeture du stream
    try {
      print('💾 [TelemetryRecorder] Appel storage.saveSession()...');
      _saveFuture = storage.saveSession(sessionId, controller.stream);
      print('✅ [TelemetryRecorder] saveSession lancé (pas attendu)');
      // Ne pas await ici ! Le stream doit rester ouvert
    } catch (e, st) {
      _state = RecorderState.error;
      print('❌ [TelemetryRecorder] Erreur appel saveSession: $e');
      print('   StackTrace: $st');
      _addError('Erreur lancement saveSession: $e', e, st);
      rethrow;
    }
  }

  /// Arrêter l'enregistrement en cours
  ///
  /// Retourne les métadonnées de la session enregistrée.
  /// Lance une exception s'il n'y a pas d'enregistrement en cours.
  Future<SessionMetadata> stopRecording() async {
    print('⏹️ [TelemetryRecorder] Arrêt enregistrement demandé');
    
    if (_state != RecorderState.recording && _state != RecorderState.error) {
      print('❌ [TelemetryRecorder] État invalide pour stop: $_state');
      throw Exception('Aucun enregistrement en cours (état: $_state)');
    }

    final sessionId = _currentSessionId;
    if (sessionId == null) {
      print('❌ [TelemetryRecorder] Pas de session active');
      throw Exception('Pas de session active');
    }

    print('🛑 [TelemetryRecorder] Arrêt session: $sessionId');
    print('📊 [TelemetryRecorder] Snapshots enregistrés: $_snapshotCount');
    print('⏱️ [TelemetryRecorder] Durée: ${elapsedTime.inSeconds}s');

    // Arrêter la souscription au bus
    print('📡 [TelemetryRecorder] Annulation subscription du bus...');
    await _subscription?.cancel();
    _subscription = null;
    print('✅ [TelemetryRecorder] Subscription annulée');

    // Fermer le controller pour signaler la fin du stream
    print('🔐 [TelemetryRecorder] Fermeture du controller...');
    await _controller?.close();
    _controller = null;
    print('✅ [TelemetryRecorder] Controller fermé');

    // IMPORTANT: Attendre que saveSession() se termine
    // C'est crucial - saveSession() écoute le stream qu'on vient de fermer
    if (_saveFuture != null) {
      print('⏳ [TelemetryRecorder] Attente fin saveSession()...');
      try {
        // Ajouter un timeout pour éviter l'attente infinie
        await _saveFuture!.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⚠️ [TelemetryRecorder] Timeout saveSession après 5s');
          },
        );
        print('✅ [TelemetryRecorder] saveSession() terminé');
      } catch (e) {
        print('⚠️ [TelemetryRecorder] Erreur saveSession: $e');
        // Ne pas rethrow ici, on veut quand même essayer de récupérer les métadonnées
      }
      _saveFuture = null;
    }

    // Attendre que la sauvegarde soit terminée
    _state = RecorderState.idle;
    print('✅ [TelemetryRecorder] État: IDLE');

    // Récupérer les métadonnées
    print('📂 [TelemetryRecorder] Récupération metadata...');
    final metadata = await storage.getSessionMetadata(sessionId);
    print('✅ [TelemetryRecorder] Metadata récupérée:');
    print('   - ID: ${metadata.sessionId}');
    print('   - Snapshots: ${metadata.snapshotCount}');
    print('   - Taille: ${metadata.sizeBytes} bytes');
    print('   - Durée: ${metadata.endTime.difference(metadata.startTime).inSeconds}s');

    // Réinitialiser l'état
    _currentSessionId = null;
    _recordingStartTime = null;

    print('✅ [TelemetryRecorder] Session arrêtée avec succès');
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
