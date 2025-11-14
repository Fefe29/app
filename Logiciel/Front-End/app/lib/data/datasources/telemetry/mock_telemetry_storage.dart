/// Implémentation Mock de TelemetryStorage pour les tests unitaires.
/// 
/// Stocke les données en mémoire, sans I/O disque.
/// Utile pour:
/// - Tests unitaires rapides
/// - Développement sans dépendance filesystem
/// - Scénarios reproductibles
/// 
/// Exemple:
/// ```dart
/// test('enregistrement session', () async {
///   final storage = MockTelemetryStorage();
///   final stream = Stream.fromIterable([snapshot1, snapshot2]);
///   
///   await storage.saveSession('test', stream);
///   final snapshots = await storage.loadSession('test');
///   
///   expect(snapshots.length, 2);
/// });
/// ```

import 'package:kornog/domain/entities/telemetry.dart';
import 'telemetry_storage.dart';

class MockTelemetryStorage implements TelemetryStorage {
  /// Stockage en mémoire : sessionId -> liste de snapshots
  final Map<String, List<TelemetrySnapshot>> _sessions = {};

  /// Métadonnées en cache
  final Map<String, SessionMetadata> _metadata = {};

  /// Historique des appels pour vérification dans les tests
  final List<String> _callLog = [];

  /// Getter pour inspections dans les tests
  List<String> get callLog => List.unmodifiable(_callLog);

  /// Nombre de sessions stockées
  int get sessionCount => _sessions.length;

  /// Lister les IDs de session
  List<String> get sessionIds => _sessions.keys.toList();

  @override
  Future<void> saveSession(
    String sessionId,
    Stream<TelemetrySnapshot> snapshots,
  ) async {
    _callLog.add('saveSession($sessionId)');

    if (_sessions.containsKey(sessionId)) {
      throw Exception('Session $sessionId already exists');
    }

    final snapshotList = <TelemetrySnapshot>[];
    DateTime? firstTs;
    DateTime? lastTs;

    await for (final snapshot in snapshots) {
      snapshotList.add(snapshot);
      firstTs ??= snapshot.ts;
      lastTs = snapshot.ts;
    }

    _sessions[sessionId] = snapshotList;

    if (firstTs != null && lastTs != null) {
      _metadata[sessionId] = SessionMetadata(
        sessionId: sessionId,
        startTime: firstTs,
        endTime: lastTs,
        snapshotCount: snapshotList.length,
        sizeBytes: _estimateSizeBytes(snapshotList),
      );
    }
  }

  @override
  Future<List<TelemetrySnapshot>> loadSession(String sessionId) async {
    _callLog.add('loadSession($sessionId)');

    if (!_sessions.containsKey(sessionId)) {
      throw Exception('Session $sessionId not found');
    }

    return List.of(_sessions[sessionId]!);
  }

  @override
  Future<List<TelemetrySnapshot>> loadSessionFiltered(
    String sessionId,
    SessionLoadFilter filter,
  ) async {
    _callLog.add('loadSessionFiltered($sessionId, filter=$filter)');

    final snapshots = await loadSession(sessionId);

    Iterable<TelemetrySnapshot> result = snapshots;

    // Filtrer par temps
    if (filter.startTime != null) {
      result = result.where((s) => s.ts.isAfter(filter.startTime!));
    }
    if (filter.endTime != null) {
      result = result.where((s) => s.ts.isBefore(filter.endTime!));
    }

    // Filtrer par métrique
    if (filter.metricKeyFilter != null) {
      final pattern = _globToRegex(filter.metricKeyFilter!);
      result = result.map((snapshot) {
        final filteredMetrics = <String, Measurement>{};
        for (final entry in snapshot.metrics.entries) {
          if (pattern.hasMatch(entry.key)) {
            filteredMetrics[entry.key] = entry.value;
          }
        }
        return TelemetrySnapshot(
          ts: snapshot.ts,
          metrics: filteredMetrics,
          tags: snapshot.tags,
        );
      });
    }

    // Paginer
    var list = result.toList();
    if (filter.offset > 0) {
      list = list.skip(filter.offset).toList();
    }
    if (filter.limit != null) {
      list = list.take(filter.limit!).toList();
    }

    return list;
  }

  @override
  Future<List<SessionMetadata>> listSessions() async {
    _callLog.add('listSessions()');
    return _metadata.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  @override
  Future<SessionMetadata> getSessionMetadata(String sessionId) async {
    _callLog.add('getSessionMetadata($sessionId)');

    if (!_metadata.containsKey(sessionId)) {
      throw Exception('Session $sessionId not found');
    }

    return _metadata[sessionId]!;
  }

  @override
  Future<SessionStats> getSessionStats(String sessionId) async {
    _callLog.add('getSessionStats($sessionId)');

    final snapshots = await loadSession(sessionId);

    if (snapshots.isEmpty) {
      throw Exception('Session $sessionId is empty');
    }

    double sumSpeed = 0;
    double maxSpeed = 0;
    double minSpeed = double.infinity;
    double sumWindSpeed = 0;
    int windCount = 0;

    for (final snapshot in snapshots) {
      final sog = snapshot.metrics['nav.sog']?.value;
      if (sog != null) {
        sumSpeed += sog;
        maxSpeed = maxSpeed < sog ? sog : maxSpeed;
        minSpeed = minSpeed > sog ? sog : minSpeed;
      }

      final tws = snapshot.metrics['wind.tws']?.value;
      if (tws != null) {
        sumWindSpeed += tws;
        windCount++;
      }
    }

    return SessionStats(
      sessionId: sessionId,
      avgSpeed: sumSpeed / snapshots.length,
      maxSpeed: maxSpeed,
      minSpeed: minSpeed == double.infinity ? 0 : minSpeed,
      avgWindSpeed: windCount > 0 ? sumWindSpeed / windCount : 0,
      maxWindSpeed: 0,
      snapshotCount: snapshots.length,
    );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _callLog.add('deleteSession($sessionId)');

    if (!_sessions.containsKey(sessionId)) {
      throw Exception('Session $sessionId not found');
    }

    _sessions.remove(sessionId);
    _metadata.remove(sessionId);
  }

  @override
  Future<bool> sessionExists(String sessionId) async {
    _callLog.add('sessionExists($sessionId)');
    return _sessions.containsKey(sessionId);
  }

  @override
  Future<void> exportSession({
    required String sessionId,
    required String format,
    required String outputPath,
  }) async {
    _callLog.add('exportSession($sessionId, format=$format, path=$outputPath)');

    if (!_sessions.containsKey(sessionId)) {
      throw Exception('Session $sessionId not found');
    }

    // Mock: ne rien faire (les vraies implémentations écriraient un fichier)
  }

  @override
  Future<int> getSessionSizeBytes(String sessionId) async {
    _callLog.add('getSessionSizeBytes($sessionId)');

    if (!_sessions.containsKey(sessionId)) {
      throw Exception('Session $sessionId not found');
    }

    return _estimateSizeBytes(_sessions[sessionId]!);
  }

  @override
  Future<int> getTotalSizeBytes() async {
    _callLog.add('getTotalSizeBytes()');

    int total = 0;
    for (final snapshots in _sessions.values) {
      total += _estimateSizeBytes(snapshots);
    }
    return total;
  }

  @override
  Future<int> cleanupOldSessions({required int olderThanDays}) async {
    _callLog.add('cleanupOldSessions($olderThanDays)');

    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    int deleted = 0;

    final toDelete = <String>[];
    for (final entry in _metadata.entries) {
      if (entry.value.startTime.isBefore(cutoff)) {
        toDelete.add(entry.key);
      }
    }

    for (final sessionId in toDelete) {
      await deleteSession(sessionId);
      deleted++;
    }

    return deleted;
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  int _estimateSizeBytes(List<TelemetrySnapshot> snapshots) {
    // Estimation très simple : ~200 bytes par snapshot en JSON compressé
    return snapshots.length * 200;
  }

  RegExp _globToRegex(String glob) {
    final pattern = glob
        .replaceAll('.', '\\.')
        .replaceAll('*', '.*')
        .replaceAll('?', '.');
    return RegExp('^$pattern\$');
  }

  /// Vider toutes les données (utile entre tests)
  void clear() {
    _sessions.clear();
    _metadata.clear();
    _callLog.clear();
  }

  /// Vider l'historique des appels
  void clearCallLog() {
    _callLog.clear();
  }

  /// Vérifier qu'une méthode a été appelée
  bool wasCalled(String methodName) {
    return _callLog.any((call) => call.startsWith(methodName));
  }

  /// Obtenir le nombre d'appels à une méthode
  int callCount(String methodName) {
    return _callLog.where((call) => call.startsWith(methodName)).length;
  }

  /// Ajouter des données de test
  Future<void> addTestSession({
    required String sessionId,
    required List<TelemetrySnapshot> snapshots,
  }) async {
    if (snapshots.isEmpty) {
      throw Exception('Cannot add empty session');
    }

    _sessions[sessionId] = snapshots;

    final first = snapshots.first.ts;
    final last = snapshots.last.ts;

    _metadata[sessionId] = SessionMetadata(
      sessionId: sessionId,
      startTime: first,
      endTime: last,
      snapshotCount: snapshots.length,
      sizeBytes: _estimateSizeBytes(snapshots),
    );
  }
}
