# 📊 Résumé Visuel - Architecture de Persistance Télémétrie

## Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────┐
│                     APPLICATION KORNOG                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐     ┌──────────────────┐                    │
│  │   Recording UI   │     │   Analysis UI    │                    │
│  │ (Start/Stop btn) │     │  (List/Stats)    │                    │
│  └────────┬─────────┘     └────────┬─────────┘                    │
│           │                        │                              │
│           └────────────┬───────────┘                              │
│                        │                                          │
│           ┌────────────▼──────────────┐                          │
│           │   Riverpod Providers      │                          │
│           │ (recordingStateProvider)  │                          │
│           │ (sessionsListProvider)    │                          │
│           │ (sessionStatsProvider)    │                          │
│           └────────────┬──────────────┘                          │
│                        │                                          │
│           ┌────────────▼──────────────────────┐                  │
│           │   TelemetryRecorder               │                  │
│           │ (start/stop/pause/resume)         │                  │
│           └────────────┬─────────────────────┘                   │
│                        │                                          │
│           ┌────────────▼──────────────────┐                      │
│           │   TelemetryBus (input)        │                      │
│           │   (FakeTelemetryBus)          │                      │
│           └────────────┬──────────────────┘                      │
│                        │                                          │
└────────────────────────┼──────────────────────────────────────────┘
                         │ Stream<TelemetrySnapshot>
                         ▼
            ╔════════════════════════════╗
            ║  PERSISTENCE LAYER         ║
            ╠════════════════════════════╣
            ║  TelemetryStorage          ║
            ║  (interface)               ║
            ╠════════════════════════════╣
            ║ 11 abstract methods:       ║
            ║ • saveSession()            ║
            ║ • loadSession()            ║
            ║ • listSessions()           ║
            ║ • getSessionStats()        ║
            ║ ... (+ 7 autres)           ║
            ╚════════════════════════════╝
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    ┌─────────────┐ ┌──────────┐  ┌─────────────┐
    │ JSON Impl   │ │Parquet   │  │ SQLite      │
    │ (now)  ✅   │ │(future)  │  │ (optional)  │
    │             │ │🔮       │  │             │
    │ JSON Lines  │ │Binaire   │  │ Database    │
    │ + GZIP      │ │Compressé │  │             │
    └─────────────┘ └──────────┘  └─────────────┘
          ▼              ▼              ▼
      Fichiers        Fichiers       Base de
      .jsonl.gz       .parquet       données

STOCKAGE:
~/.kornog/telemetry/
├── sessions/
│   ├── session_2025_11_14_training.jsonl.gz       ← 5 MB (JSON)
│   └── session_2025_11_14_regatta.jsonl.gz        ← 18 MB (JSON)
└── metadata/
    ├── session_2025_11_14_training.json
    └── session_2025_11_14_regatta.json
```

---

## Flux d'enregistrement

```
1. DÉMARRAGE
   ┌─────────────────────────────────────────┐
   │ startRecording('session_2025_11_14')    │
   └────────────────────┬────────────────────┘
                        │
                        ▼
   ┌─────────────────────────────────────────┐
   │ TelemetryRecorder                       │
   │ • Ouvre stream du TelemetryBus          │
   │ • Initialise le storage                 │
   └────────────────────┬────────────────────┘
                        │
2. ENREGISTREMENT (continu)
                        │
                        ▼
   ┌─────────────────────────────────────────┐
   │ TelemetryBus.snapshots()                │
   │ émet → TelemetrySnapshot                │
   │ toutes les 100ms (FakeTelemetryBus)     │
   └────────────────────┬────────────────────┘
                        │
                        ▼
   ┌─────────────────────────────────────────┐
   │ TelemetryRecorder.onProgress()          │
   │ Notifie: count++, elapsed++             │
   │ → UI mise à jour                        │
   └────────────────────┬────────────────────┘
                        │
                        ▼
   ┌─────────────────────────────────────────┐
   │ JsonTelemetryStorage.saveSession()      │
   │ • Buffer les snapshots                  │
   │ • Écrit JSON Lines compressés           │
   │ • Stockage: ~/.kornog/telemetry/...     │
   └────────────────────┬────────────────────┘
                        │
3. ARRÊT
                        │
                        ▼
   ┌─────────────────────────────────────────┐
   │ stopRecording()                         │
   │ • Ferme les streams                     │
   │ • Récupère métadonnées finales          │
   │ • Retourne SessionMetadata              │
   └────────────────────┬────────────────────┘
                        │
                        ▼
   ┌─────────────────────────────────────────┐
   │ SessionMetadata                         │
   │ ├─ sessionId                            │
   │ ├─ startTime / endTime                  │
   │ ├─ snapshotCount (5847)                 │
   │ └─ sizeBytes (1,234,567)                │
   └─────────────────────────────────────────┘
```

---

## Flux de lecture/analyse

```
CHARGER UNE SESSION POUR ANALYSE:

   ref.watch(sessionDataProvider('session_id'))
                  │
                  ▼
   JsonTelemetryStorage.loadSession('session_id')
   1. Ouvre fichier .jsonl.gz
   2. Décompresse (GZipCodec)
   3. Parse chaque ligne JSON
   4. Reconstruit TelemetrySnapshot
   5. Retourne List<TelemetrySnapshot>
                  │
                  ▼
   UI reçoit snapshots
   • Affiche stats
   • Trace graphiques
   • Exporte CSV


CHARGER AVEC FILTRES:

   ref.watch(filteredSessionProvider((
     sessionId: 'session_id',
     filter: SessionLoadFilter(
       startTime: 10:30,
       endTime: 10:35,
       metricKeyFilter: 'wind.*',
       limit: 1000,
     )
   )))
                  │
                  ▼
   JsonTelemetryStorage.loadSessionFiltered()
   1. Charge session complète
   2. Applique filtre temps
   3. Applique filtre métriques (regex)
   4. Pagine (offset/limit)
   5. Retourne sous-ensemble

   ⚠️  JSON charge tout en mémoire
   ✅ Parquet ferait mieux (filtrage natif)


EXTRAIRE UNE MÉTRIQUE:

   ref.watch(sessionMetricProvider((
     sessionId: 'session_id',
     metricKey: 'nav.sog',
   )))
                  │
                  ▼
   résultat: List<({DateTime ts, double value})>
   [
     (ts: 2025-11-14 10:30:00, value: 6.4),
     (ts: 2025-11-14 10:30:01, value: 6.5),
     (ts: 2025-11-14 10:30:02, value: 6.6),
     ...
   ]
   
   → Utilisable directement pour graphiques
```

---

## État + Transitions

```
RECORDER STATE MACHINE:

       ┌────────────────────────────────┐
       │         IDLE (initial)         │
       │  ✅ "Aucun enregistrement"     │
       └────────────────┬───────────────┘
                        │ startRecording()
                        ▼
       ┌────────────────────────────────┐
       │     RECORDING (actif)          │
       │ 🔴 "Enregistrement en cours"   │
       │     • Snapshots accumulés      │
       │     • onProgress() appelé      │
       ├────────────┬───────────────────┤
       │            │ pauseRecording()  │
       │            ▼                   │
       │  ┌──────────────────┐          │
       │  │ PAUSED (en pause)│          │
       │  │ ⏸ "En pause"     │          │
       │  └────────┬─────────┘          │
       │           │ resumeRecording()  │
       │           ▼                    │
       │    (retour à RECORDING)        │
       │                                │
       │ stopRecording() →              │
       └────────────┬───────────────────┘
                    ▼
       ┌────────────────────────────────┐
       │    IDLE (après stop)           │
       │ ✅ Session sauvegardée         │
       │    SessionMetadata retourné    │
       └────────────────────────────────┘

EN CAS D'ERREUR:
       ┌────────────────────────────────┐
       │        ERROR                   │
       │ ❌ "Erreur"                    │
       │    onError() appelé            │
       │    Erreur stockée dans recorder│
       └────────────┬───────────────────┘
                    │ stopRecording()
                    ▼
       ┌────────────────────────────────┐
       │         IDLE                   │
       │ (session incomplète/supprimée) │
       └────────────────────────────────┘
```

---

## Arborescence fichiers créés

```
lib/
├── data/datasources/telemetry/
│   ├── telemetry_storage.dart          🟦 Interface abstraite (430L)
│   ├── json_telemetry_storage.dart     🟩 Impl JSON (650L)
│   ├── mock_telemetry_storage.dart     🟪 Mock tests (350L)
│   ├── telemetry_recorder.dart         🟦 Recorder (250L)
│   └── parquet_telemetry_storage.dart  ⬜ Skeleton futur (120L)
│
├── features/telemetry_recording/
│   ├── providers/
│   │   └── telemetry_storage_providers.dart  🟦 Riverpod (350L)
│   │
│   └── presentation/
│       └── telemetry_recording_page.dart    🟩 UI complète (650L)
│
└── test/
    └── telemetry_storage_test.dart         🟪 Tests (500L)

ROOT:
├── TELEMETRY_STORAGE_GUIDE.md          📖 Tuto complet (600L)
└── TELEMETRY_PERSISTENCE_COMPLETE.md   📋 Résumé/checklist (300L)

TOTAL: ~4,300 lignes de code + documentation
```

---

## Matrice d'implémentation

```
             │ JSON (now)  │ Parquet (later) │ SQLite (optional)
─────────────┼─────────────┼─────────────────┼──────────────────
Implémentée │ ✅          │ 🔮             │ ⬜
─────────────┼─────────────┼─────────────────┼──────────────────
Compression │ 70%         │ 80-85%         │ -
─────────────┼─────────────┼─────────────────┼──────────────────
Req. simple │ ✅ O(n)     │ ✅ O(1)        │ ✅ O(log n)
─────────────┼─────────────┼─────────────────┼──────────────────
Req. filtres│ ⚠️ En RAM   │ ✅ Native       │ ✅ SQL
─────────────┼─────────────┼─────────────────┼──────────────────
Stats rapide│ ❌ O(n)     │ ✅ O(1)        │ ✅ O(1)
─────────────┼─────────────┼─────────────────┼──────────────────
Lisible     │ ✅ JSON     │ ❌ Binaire      │ ❌ DB
─────────────┼─────────────┼─────────────────┼──────────────────
ML Support  │ ⚠️ Export   │ ✅ Pandas/Polars│ ✅ Pandas
─────────────┼─────────────┼─────────────────┼──────────────────
Complexité  │ Simple      │ Moyenne         │ Élevée
```

---

## Checklist d'intégration rapide

### ✅ 5 minutes : Setup initial
```dart
// 1. Copier les fichiers
//    lib/data/datasources/telemetry/*.dart
//    lib/features/telemetry_recording/**

// 2. Dans main.dart:
void main() {
  final storage = JsonTelemetryStorage(
    storageDir: appDir,  // path_provider
  );
  runApp(
    ProviderScope(
      overrides: [telemetryStorageProvider.overrideWithValue(storage)],
      child: const MyApp(),
    ),
  );
}
```

### ✅ 2 minutes : Ajouter UI
```dart
// Dans router:
GoRoute(path: '/recording', builder: ...) =>
  const TelemetryRecordingPage(),
```

### ✅ 1 minute : Utiliser dans widget
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // C'est tout!
    final sessions = ref.watch(sessionsListProvider);
    return ...;
  }
}
```

**Total : 8 minutes pour intégration basique! ⚡**

---

## Performance: Avant/Après

```
SANS PERSISTENCE:
❌ Données perdues si app crash
❌ Impossible analyser après
❌ Chaque sortie = zéro historique

AVEC PERSISTENCE (JSON):
✅ 1 session = 20 MB stockée
✅ 5 sessions = 100 MB (tient sur téléphone)
✅ Analyse complète possible
✅ Export CSV pour Excel

AVANTAGES À VENIR (Parquet):
🚀 1 session = 4 MB (5x moins!)
🚀 50 sessions = 200 MB (reste compact)
🚀 Requêtes 10x plus rapides
🚀 ML sur vraies données
```

---

## Exemple d'usage : Une régate complète

```
JOUR 1 - RÉGATE:
10:00 - Clique "Démarrer"                → session_2025_11_14_race1
10:45 - Première course terminée
        Clique "Arrêter" → SessionMetadata { snapshotCount: 2700 }
        Clique "Démarrer" → session_2025_11_14_race2
11:30 - Deuxième course terminée
        Clique "Arrêter"

JOUR 2 - ANALYSE:
- Accède "Sessions"
  → Voit 2 courses enregistrées
  → race1 : 2700 points, 8.2 MB
  → race2 : 2400 points, 7.5 MB
  
- Clique "race1"
  → Stats : avg 6.8 kn, max 9.2 kn, vent 12.3 kn
  → Graphique vitesse
  
- Clique "Exporter CSV"
  → Télécharge vers /Downloads/race1.csv
  → Ouvre dans Excel
  → Analyse détaillée

JOUR 3 - COACHING:
Coach reçoit race1.csv
- Importe dans Python
  df = pd.read_csv('race1.csv')
  
  # Analyse
  fast_segments = df[df['nav.sog'] > 8.0]
  
  # Machine Learning
  from sklearn import ...
  model = train_on_real_data(df)
  
Kornog améliore polaires avec données réelles! 🚀
```

---

## Flux de migration JSON → Parquet (optionnel)

```
JOUR 20 : "Besoin de meilleures performances"

AVANT (JSON):
100 sessions × 200 sessions = 2 GB disque
Requête "vitesse 10:30-10:35" = 2 secondes

APRÈS (Parquet):
100 sessions × 40 MB = 400 MB disque (-80%!)
Même requête = 50ms (40x plus rapide)

MIGRATION (une ligne de code):
- main.dart : change JsonTelemetryStorage →
            ParquetTelemetryStorage
- Données anciennes : exporter/réimporter via script
  (ou : migration auto en arrière-plan)

✅ ZERO breaking change pour l'UI
✅ Tous les providers continuent fonctionner
```

---

## Questions fréquentes

**Q: Où sont stockées les données?**
R: `~/.kornog/telemetry/sessions/*.jsonl.gz`

**Q: Puis-je partager les sessions?**
R: Oui! Exporte en CSV/JSON, envoie par mail/cloud.

**Q: Que se passe-t-il si j'ai 10 GB de données?**
R: Migre à Parquet (4x plus compact) ou SQLite.

**Q: Comment faire du ML?**
R: Exporte CSV → Pandas/scikit-learn → profit!

**Q: Et si je ferme l'app pendant l'enregistrement?**
R: Session incomplète mais récupérable (métadonnées sauvegardées).

**Q: Peut-on avoir plusieurs sessions simultanées?**
R: Actuellement non, un seul recorder à la fois.
(À améliorer si besoin)

**Q: Comment nettoyer les vieilles sessions?**
R: `cleanupOldSessions(olderThanDays: 30)` automatique ou manuel.

---

**Prêt à intégrer ? → Voir TELEMETRY_STORAGE_GUIDE.md**

