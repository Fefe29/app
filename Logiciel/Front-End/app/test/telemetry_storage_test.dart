/// Exemples de tests unitaires pour la couche de persistance télémétrie.
/// 
/// À adapter et intégrer dans ton dossier test/

import 'package:flutter_test/flutter_test.dart';
import 'package:kornog/data/datasources/telemetry/mock_telemetry_storage.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_storage.dart';
import 'package:kornog/domain/entities/telemetry.dart';

void main() {
  group('MockTelemetryStorage', () {
    late MockTelemetryStorage storage;

    setUp(() {
      storage = MockTelemetryStorage();
    });

    test('Créer et charger une session', () async {
      // Créer des snapshots de test
      final now = DateTime.now();
      final snapshots = [
        TelemetrySnapshot(
          ts: now,
          metrics: {
            'nav.sog': Measurement(value: 6.4, unit: Unit.knot, ts: now),
            'wind.twd': Measurement(value: 280.5, unit: Unit.degree, ts: now),
            'wind.tws': Measurement(value: 12.3, unit: Unit.knot, ts: now),
          },
        ),
        TelemetrySnapshot(
          ts: now.add(const Duration(seconds: 1)),
          metrics: {
            'nav.sog': Measurement(value: 6.5, unit: Unit.knot, ts: now),
            'wind.twd': Measurement(value: 281.0, unit: Unit.degree, ts: now),
            'wind.tws': Measurement(value: 12.4, unit: Unit.knot, ts: now),
          },
        ),
      ];

      // Sauvegarder
      await storage.saveSession('test_session', Stream.fromIterable(snapshots));

      // Charger
      final loaded = await storage.loadSession('test_session');

      // Vérifier
      expect(loaded.length, 2);
      expect(loaded[0].metrics['nav.sog']?.value, 6.4);
      expect(loaded[1].metrics['wind.twd']?.value, 281.0);
    });

    test('Lister les sessions', () async {
      // Créer plusieurs sessions
      final now = DateTime.now();
      final snapshot1 = TelemetrySnapshot(
        ts: now,
        metrics: {'nav.sog': Measurement(value: 6.0, unit: Unit.knot, ts: now)},
      );
      final snapshot2 = snapshot1.copyWith(
        ts: now.add(const Duration(seconds: 1)),
      );

      await storage.saveSession('session_1', Stream.fromIterable([snapshot1]));
      await storage.saveSession('session_2', Stream.fromIterable([snapshot2]));

      // Lister
      final sessions = await storage.listSessions();

      expect(sessions.length, 2);
      expect(sessions[0].sessionId, isIn(['session_1', 'session_2']));
    });

    test('Obtenir les stats d\'une session', () async {
      final now = DateTime.now();
      final snapshots = [
        TelemetrySnapshot(
          ts: now,
          metrics: {
            'nav.sog': Measurement(value: 5.0, unit: Unit.knot, ts: now),
            'wind.tws': Measurement(value: 10.0, unit: Unit.knot, ts: now),
          },
        ),
        TelemetrySnapshot(
          ts: now.add(const Duration(seconds: 1)),
          metrics: {
            'nav.sog': Measurement(value: 7.0, unit: Unit.knot, ts: now),
            'wind.tws': Measurement(value: 12.0, unit: Unit.knot, ts: now),
          },
        ),
        TelemetrySnapshot(
          ts: now.add(const Duration(seconds: 2)),
          metrics: {
            'nav.sog': Measurement(value: 6.0, unit: Unit.knot, ts: now),
            'wind.tws': Measurement(value: 11.0, unit: Unit.knot, ts: now),
          },
        ),
      ];

      await storage.saveSession('test_stats', Stream.fromIterable(snapshots));

      final stats = await storage.getSessionStats('test_stats');

      expect(stats.snapshotCount, 3);
      expect(stats.avgSpeed, 6.0); // (5 + 7 + 6) / 3
      expect(stats.maxSpeed, 7.0);
      expect(stats.minSpeed, 5.0);
      expect(stats.avgWindSpeed, 11.0); // (10 + 12 + 11) / 3
    });

    test('Supprimer une session', () async {
      final now = DateTime.now();
      final snapshot = TelemetrySnapshot(
        ts: now,
        metrics: {'nav.sog': Measurement(value: 6.0, unit: Unit.knot, ts: now)},
      );

      await storage.saveSession('to_delete', Stream.fromIterable([snapshot]));
      expect(await storage.sessionExists('to_delete'), true);

      await storage.deleteSession('to_delete');
      expect(await storage.sessionExists('to_delete'), false);
    });

    test('Filtrer par temps', () async {
      final base = DateTime(2025, 11, 14, 10, 0, 0);
      final snapshots = [
        TelemetrySnapshot(
          ts: base,
          metrics: {'nav.sog': Measurement(value: 6.0, unit: Unit.knot, ts: base)},
        ),
        TelemetrySnapshot(
          ts: base.add(const Duration(seconds: 10)),
          metrics: {'nav.sog': Measurement(value: 6.5, unit: Unit.knot, ts: base)},
        ),
        TelemetrySnapshot(
          ts: base.add(const Duration(seconds: 20)),
          metrics: {'nav.sog': Measurement(value: 7.0, unit: Unit.knot, ts: base)},
        ),
      ];

      await storage.saveSession('time_filter', Stream.fromIterable(snapshots));

      final filter = SessionLoadFilter(
        startTime: base.add(const Duration(seconds: 5)),
        endTime: base.add(const Duration(seconds: 15)),
      );

      final filtered =
          await storage.loadSessionFiltered('time_filter', filter);

      expect(filtered.length, 1);
      expect(filtered[0].metrics['nav.sog']?.value, 6.5);
    });

    test('Filtrer par métrique (glob pattern)', () async {
      final now = DateTime.now();
      final snapshot = TelemetrySnapshot(
        ts: now,
        metrics: {
          'nav.sog': Measurement(value: 6.0, unit: Unit.knot, ts: now),
          'nav.hdg': Measurement(value: 45.0, unit: Unit.degree, ts: now),
          'wind.twd': Measurement(value: 280.0, unit: Unit.degree, ts: now),
          'wind.tws': Measurement(value: 12.0, unit: Unit.knot, ts: now),
        },
      );

      await storage.saveSession('metric_filter', Stream.fromIterable([snapshot]));

      // Filtrer pour n'avoir que le vent
      final filter = SessionLoadFilter(metricKeyFilter: 'wind.*');

      final filtered =
          await storage.loadSessionFiltered('metric_filter', filter);

      expect(filtered[0].metrics.length, 2);
      expect(filtered[0].metrics.containsKey('wind.twd'), true);
      expect(filtered[0].metrics.containsKey('wind.tws'), true);
      expect(filtered[0].metrics.containsKey('nav.sog'), false);
    });

    test('Paginer les résultats', () async {
      final now = DateTime.now();
      final snapshots = [
        for (int i = 0; i < 150; i++)
          TelemetrySnapshot(
            ts: now.add(Duration(seconds: i)),
            metrics: {
              'nav.sog': Measurement(
                value: 5.0 + i * 0.1,
                unit: Unit.knot,
                ts: now,
              ),
            },
          ),
      ];

      await storage.saveSession('pagination', Stream.fromIterable(snapshots));

      // Page 1 : 50 premiers
      final page1 = await storage.loadSessionFiltered(
        'pagination',
        SessionLoadFilter(limit: 50, offset: 0),
      );
      expect(page1.length, 50);
      expect(page1[0].metrics['nav.sog']?.value, 5.0);

      // Page 2 : 50 suivants
      final page2 = await storage.loadSessionFiltered(
        'pagination',
        SessionLoadFilter(limit: 50, offset: 50),
      );
      expect(page2.length, 50);
      expect(page2[0].metrics['nav.sog']?.value, closeTo(10.0, 0.1));
    });

    test('Nettoyage des anciennes sessions', () async {
      final now = DateTime.now();
      final snapshot = TelemetrySnapshot(
        ts: now,
        metrics: {'nav.sog': Measurement(value: 6.0, unit: Unit.knot, ts: now)},
      );

      // Session actuelle
      await storage.saveSession('recent', Stream.fromIterable([snapshot]));

      // Session ancienne (32 jours)
      final old = now.subtract(const Duration(days: 32));
      final oldSnapshot = TelemetrySnapshot(
        ts: old,
        metrics: {'nav.sog': Measurement(value: 6.0, unit: Unit.knot, ts: old)},
      );
      await storage.addTestSession(sessionId: 'old', snapshots: [oldSnapshot]);

      // Nettoyer
      final deleted = await storage.cleanupOldSessions(olderThanDays: 30);

      expect(deleted, 1);
      expect(await storage.sessionExists('recent'), true);
      expect(await storage.sessionExists('old'), false);
    });

    test('Verifier les appels de méthode', () async {
      await storage.listSessions();
      await storage.listSessions();

      expect(storage.wasCalled('listSessions'), true);
      expect(storage.callCount('listSessions'), 2);
      expect(storage.wasCalled('saveSession'), false);
    });

    test('Espace disque utilisé', () async {
      final now = DateTime.now();
      final snapshots = [
        TelemetrySnapshot(
          ts: now,
          metrics: {'nav.sog': Measurement(value: 6.0, unit: Unit.knot, ts: now)},
        ),
      ];

      await storage.saveSession('session_1', Stream.fromIterable(snapshots));
      await storage.saveSession('session_2', Stream.fromIterable(snapshots));

      final total = await storage.getTotalSizeBytes();
      expect(total, greaterThan(0));
    });

    test('Session inexistante lève une exception', () async {
      expect(
        () => storage.loadSession('non_existent'),
        throwsException,
      );
    });

    test('Erreur si session existe déjà', () async {
      final now = DateTime.now();
      final snapshot = TelemetrySnapshot(
        ts: now,
        metrics: {'nav.sog': Measurement(value: 6.0, unit: Unit.knot, ts: now)},
      );

      await storage.saveSession('dup', Stream.fromIterable([snapshot]));

      expect(
        () => storage.saveSession('dup', Stream.fromIterable([snapshot])),
        throwsException,
      );
    });

    test('Clear et reset pour tests isolés', () async {
      final now = DateTime.now();
      final snapshot = TelemetrySnapshot(
        ts: now,
        metrics: {'nav.sog': Measurement(value: 6.0, unit: Unit.knot, ts: now)},
      );

      await storage.saveSession('session', Stream.fromIterable([snapshot]));
      expect(storage.sessionCount, 1);

      storage.clear();
      expect(storage.sessionCount, 0);
    });
  });

  group('SessionMetadata', () {
    test('Calcul de la durée', () {
      final start = DateTime(2025, 11, 14, 10, 0, 0);
      final end = DateTime(2025, 11, 14, 11, 30, 0);

      final metadata = SessionMetadata(
        sessionId: 'test',
        startTime: start,
        endTime: end,
        snapshotCount: 100,
        sizeBytes: 50000,
      );

      expect(metadata.duration.inMinutes, 90);
    });

    test('ToString inclut les infos', () {
      final metadata = SessionMetadata(
        sessionId: 'test',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        snapshotCount: 100,
        sizeBytes: 50000,
      );

      final str = metadata.toString();
      expect(str, contains('test'));
      expect(str, contains('100 points'));
      expect(str, contains('KB'));
    });
  });

  group('SessionStats', () {
    test('ToString inclut les stats', () {
      final stats = SessionStats(
        sessionId: 'test',
        avgSpeed: 6.5,
        maxSpeed: 8.0,
        minSpeed: 5.0,
        avgWindSpeed: 12.0,
        maxWindSpeed: 15.0,
        minWindSpeed: 8.0,
        snapshotCount: 100,
      );

      final str = stats.toString();
      expect(str, contains('test'));
      expect(str, contains('6.5'));
    });
  });

  group('SessionLoadFilter', () {
    test('Détecte les filtres appliqués', () {
      final withTime = SessionLoadFilter(
        startTime: DateTime.now(),
      );
      expect(withTime.hasTimeRange, true);
      expect(withTime.hasMetricFilter, false);

      final withMetric = SessionLoadFilter(
        metricKeyFilter: 'wind.*',
      );
      expect(withMetric.hasTimeRange, false);
      expect(withMetric.hasMetricFilter, true);

      final both = SessionLoadFilter(
        startTime: DateTime.now(),
        metricKeyFilter: 'wind.*',
      );
      expect(both.hasTimeRange, true);
      expect(both.hasMetricFilter, true);
    });
  });
}

// ============================================================================
// Extension helper pour TelemetrySnapshot (facilite les tests)
// ============================================================================

extension TelemetrySnapshotTestHelpers on TelemetrySnapshot {
  /// Créer une copie avec des champs modifiés
  TelemetrySnapshot copyWith({
    DateTime? ts,
    Map<String, Measurement>? metrics,
    Map<String, Object?>? tags,
  }) {
    return TelemetrySnapshot(
      ts: ts ?? this.ts,
      metrics: metrics ?? this.metrics,
      tags: tags ?? this.tags,
    );
  }
}
