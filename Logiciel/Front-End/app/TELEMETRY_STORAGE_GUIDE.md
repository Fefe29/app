/// Guide d'intégration complète de la couche de persistance télémétrique.
/// 
/// Ce fichier documente comment intégrer et utiliser le système de persistence
/// des données du bateau dans ton application Kornog.
/// 
/// Voir aussi:
/// - IMPLEMENTATION_CHECKLIST.md
/// - ARCHITECTURE_DOCS.md

/*
================================================================================
  GUIDE D'INTÉGRATION - TELEMETRY STORAGE LAYER
================================================================================

## 📋 Table des matières
1. Structure des fichiers
2. Configuration initiale
3. Enregistrement des données
4. Lecture et analyse
5. Tests
6. Migration vers Parquet

================================================================================
## 1. STRUCTURE DES FICHIERS
================================================================================

Les fichiers créés :

lib/data/datasources/telemetry/
├── telemetry_storage.dart           ← Interface abstraite (14 fichiers)
├── json_telemetry_storage.dart      ← Implémentation JSON (400 lignes)
├── mock_telemetry_storage.dart      ← Mock pour tests (350 lignes)
└── telemetry_recorder.dart          ← Enregistreur (250 lignes)

lib/features/telemetry_recording/
└── providers/
    └── telemetry_storage_providers.dart  ← Providers Riverpod (300 lignes)

================================================================================
## 2. CONFIGURATION INITIALE
================================================================================

### Étape 1: Initialiser dans main.dart

```dart
import 'package:path_provider/path_provider.dart';
import 'package:kornog/data/datasources/telemetry/json_telemetry_storage.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration du storage
  final appDir = await getApplicationDocumentsDirectory();
  final storage = JsonTelemetryStorage(storageDir: appDir);

  // Provider override
  runApp(
    ProviderScope(
      overrides: [
        telemetryStorageProvider.overrideWithValue(storage),
        // ... autres overrides
      ],
      child: const MyApp(),
    ),
  );
}
```

### Étape 2: Vérifier les permissions

Android (AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

iOS (Info.plist):
```xml
<key>NSLocalizedDescription</key>
<string>Accès aux documents pour enregistrer les sessions</string>
```

================================================================================
## 3. ENREGISTREMENT DES DONNÉES
================================================================================

### Cas A : Enregistrement simple (bouton start/stop)

```dart
class RecordingButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorder = ref.watch(telemetryRecorderProvider);
    final recordingState = ref.watch(recordingStateProvider);

    return Column(
      children: [
        ElevatedButton(
          onPressed: recordingState != RecorderState.recording
              ? () async {
                  final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
                  try {
                    await ref.read(recordingStateProvider.notifier)
                        .startRecording(sessionId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Enregistrement: $sessionId')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              : null,
          child: const Text('Démarrer'),
        ),
        ElevatedButton(
          onPressed: recordingState == RecorderState.recording
              ? () async {
                  final metadata = await ref
                      .read(recordingStateProvider.notifier)
                      .stopRecording();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Session sauvegardée: ${metadata.snapshotCount} points',
                      ),
                    ),
                  );
                }
              : null,
          child: const Text('Arrêter'),
        ),
      ],
    );
  }
}
```

### Cas B : Enregistrement avec callbacks de progrès

```dart
class RecordingWithProgress extends ConsumerStatefulWidget {
  @override
  ConsumerState<RecordingWithProgress> createState() =>
      _RecordingWithProgressState();
}

class _RecordingWithProgressState extends ConsumerState<RecordingWithProgress> {
  int _snapshotCount = 0;
  Duration _elapsed = Duration.zero;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Snapshots: $_snapshotCount'),
        Text('Durée: ${_elapsed.inSeconds}s'),
        ElevatedButton(
          onPressed: () async {
            final recorder = ref.read(telemetryRecorderProvider);

            // Ajouter des callbacks
            recorder.onProgress = (count, elapsed) {
              setState(() {
                _snapshotCount = count;
                _elapsed = elapsed;
              });
            };

            await recorder.startRecording('session_${DateTime.now().millisecondsSinceEpoch}');
          },
          child: const Text('Commencer'),
        ),
      ],
    );
  }
}
```

### Cas C : Pause/Reprise

```dart
// Pausser l'enregistrement
ref.read(recordingStateProvider.notifier).pauseRecording();

// Reprendre
ref.read(recordingStateProvider.notifier).resumeRecording();
```

================================================================================
## 4. LECTURE ET ANALYSE
================================================================================

### Afficher la liste des sessions

```dart
class SessionsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsListProvider);

    return sessionsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, st) => Text('Erreur: $err'),
      data: (sessions) => ListView.builder(
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
          return ListTile(
            title: Text(session.sessionId),
            subtitle: Text(
              '${session.snapshotCount} points • '
              '${(session.sizeBytes / 1024).toStringAsFixed(1)} KB',
            ),
            onTap: () {
              // Voir les détails/analyser
            },
          );
        },
      ),
    );
  }
}
```

### Afficher les stats d'une session

```dart
class SessionStats extends ConsumerWidget {
  final String sessionId;

  const SessionStats({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(sessionStatsProvider(sessionId));

    return statsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, st) => Text('Erreur: $err'),
      data: (stats) => Column(
        children: [
          Text('Vitesse moyenne: ${stats.avgSpeed.toStringAsFixed(1)} kn'),
          Text('Vitesse max: ${stats.maxSpeed.toStringAsFixed(1)} kn'),
          Text('Vitesse vent: ${stats.avgWindSpeed.toStringAsFixed(1)} kn'),
          Text('Nombre de points: ${stats.snapshotCount}'),
        ],
      ),
    );
  }
}
```

### Charger une session complète pour analyse

```dart
final snapshots = await ref.read(sessionDataProvider('session_id').future);

// Analyser les données
double avgSpeed = 0;
for (final snapshot in snapshots) {
  final sog = snapshot.metrics['nav.sog']?.value ?? 0;
  avgSpeed += sog;
}
avgSpeed /= snapshots.length;

print('Vitesse moyenne: $avgSpeed kn');
```

### Charger avec filtres (temps, métrique)

```dart
final filter = SessionLoadFilter(
  startTime: DateTime.now().subtract(Duration(hours: 1)),
  endTime: DateTime.now(),
  metricKeyFilter: 'wind.*',  // Seulement les données de vent
  limit: 1000,
);

final filteredSnapshots = await ref.read(
  filteredSessionProvider(
    (sessionId: 'session_id', filter: filter),
  ).future,
);
```

### Extraire une métrique spécifique

```dart
final speedData = await ref.read(
  sessionMetricProvider(
    (sessionId: 'session_id', metricKey: 'nav.sog'),
  ).future,
);

// speedData = [(ts: DateTime(...), value: 6.4), (ts: DateTime(...), value: 6.5), ...]

// Utilisable directement pour un graphique
final chartData = speedData
    .map((point) => FlSpot(
          point.ts.millisecondsSinceEpoch.toDouble(),
          point.value,
        ))
    .toList();
```

### Supprimer une session

```dart
await ref.read(sessionManagementProvider).deleteSession('session_id');

// Les UI se mettront à jour automatiquement via invalide
```

### Exporter une session

```dart
await ref.read(sessionManagementProvider).exportSession(
  sessionId: 'session_id',
  format: 'csv',  // ou 'json' ou 'jsonl'
  outputPath: '/path/to/export.csv',
);
```

### Nettoyage automatique des anciennes sessions

```dart
// Supprimer les sessions de plus de 30 jours
final deletedCount = await ref
    .read(sessionManagementProvider)
    .cleanupOldSessions(olderThanDays: 30);

print('Supprimées: $deletedCount sessions');
```

================================================================================
## 5. TESTS
================================================================================

### Test unitaire simple

```dart
test('enregistrer et charger une session', () async {
  final storage = MockTelemetryStorage();

  // Créer des snapshots de test
  final snapshots = [
    TelemetrySnapshot(
      ts: DateTime.now(),
      metrics: {
        'nav.sog': Measurement(value: 6.4, unit: Unit.knot, ts: DateTime.now()),
        'wind.twd': Measurement(value: 280.5, unit: Unit.degree, ts: DateTime.now()),
      },
    ),
    TelemetrySnapshot(
      ts: DateTime.now().add(Duration(seconds: 1)),
      metrics: {
        'nav.sog': Measurement(value: 6.5, unit: Unit.knot, ts: DateTime.now()),
        'wind.twd': Measurement(value: 281.0, unit: Unit.degree, ts: DateTime.now()),
      },
    ),
  ];

  // Sauvegarder
  await storage.saveSession('test_session', Stream.fromIterable(snapshots));

  // Charger
  final loaded = await storage.loadSession('test_session');

  expect(loaded.length, 2);
  expect(loaded[0].metrics['nav.sog']?.value, 6.4);
});
```

### Test avec MockTelemetryStorage

```dart
test('verifier les appels de méthode', () async {
  final storage = MockTelemetryStorage();

  // Faire des appels
  await storage.listSessions();
  await storage.listSessions();

  // Vérifier
  expect(storage.wasCalled('listSessions'), true);
  expect(storage.callCount('listSessions'), 2);
});
```

### Test avec Riverpod

```dart
test('provider de recordings', (WidgetTester tester) async {
  final mockStorage = MockTelemetryStorage();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        telemetryStorageProvider.overrideWithValue(mockStorage),
      ],
      child: const MyApp(),
    ),
  );

  // Test le provider
  expect(find.byType(RecordingButton), findsOneWidget);
});
```

================================================================================
## 6. MIGRATION VERS PARQUET (FUTUR)
================================================================================

Quand tu voudras passer à Parquet :

1. Créer ParquetTelemetryStorage implémentant TelemetryStorage
2. Changer une ligne dans main.dart:

```dart
// Avant
final storage = JsonTelemetryStorage(storageDir: appDir);

// Après
final storage = ParquetTelemetryStorage(storageDir: appDir);
```

3. Migration automatique (optionnel):

```dart
class StorageMigration {
  static Future<void> migrateJsonToParquet(
    TelemetryStorage jsonStorage,
    TelemetryStorage parquetStorage,
  ) async {
    final sessions = await jsonStorage.listSessions();
    
    for (final session in sessions) {
      final snapshots = await jsonStorage.loadSession(session.sessionId);
      await parquetStorage.saveSession(
        session.sessionId,
        Stream.fromIterable(snapshots),
      );
    }
  }
}
```

================================================================================
## 7. ARBORESCENCE FINALE DES FICHIERS
================================================================================

```
~/.kornog/telemetry/
├── sessions/
│   ├── session_2025_11_14_training.jsonl.gz     (5 MB)
│   ├── session_2025_11_14_regatta_race1.jsonl.gz (18 MB)
│   └── session_2025_11_15_coaching.jsonl.gz     (8 MB)
└── metadata/
    ├── session_2025_11_14_training.json
    ├── session_2025_11_14_regatta_race1.json
    └── session_2025_11_15_coaching.json
```

Chaque session .jsonl.gz contient des lignes JSON compressées:
```
{"ts":"2025-11-14T10:30:00Z","metrics":{"nav.sog":6.4,"wind.twd":280.5}}
{"ts":"2025-11-14T10:30:01Z","metrics":{"nav.sog":6.5,"wind.twd":281.0}}
...
```

================================================================================
## 8. CHECKLIST D'INTÉGRATION
================================================================================

- [ ] Fichiers créés:
  - [ ] telemetry_storage.dart (interface)
  - [ ] json_telemetry_storage.dart (impl)
  - [ ] telemetry_recorder.dart (recorder)
  - [ ] mock_telemetry_storage.dart (tests)
  - [ ] telemetry_storage_providers.dart (riverpod)

- [ ] Configuration:
  - [ ] Override providers dans main.dart
  - [ ] Permissions Android/iOS configurées
  - [ ] path_provider dans pubspec.yaml (✅ déjà présent)

- [ ] Widgets créés:
  - [ ] RecordingButton (start/stop)
  - [ ] SessionsList (affichage sessions)
  - [ ] SessionStats (stats d'une session)

- [ ] Tests:
  - [ ] Tests unitaires avec MockTelemetryStorage
  - [ ] Tests d'intégration des providers

- [ ] Documentation:
  - [ ] Mise à jour ARCHITECTURE_DOCS.md
  - [ ] Exemples d'utilisation documentés

================================================================================
*/

// Ce fichier est à titre informatif uniquement.
// Voir les fichiers actuels pour l'implémentation.
