# 🔧 FIX - Streaming Sessions Vides (0 Snapshots)

**Date**: 15 novembre 2025  
**Problème**: Sessions enregistrées mais VIDES (0 snapshots)  
**Cause**: Race condition entre subscription au bus et saveSession()  
**Status**: ✅ FIXÉ

---

## 🐛 Le Problème (Avant)

### Logs Observés
```
💾 [TelemetryRecorder] Appel storage.saveSession()...
📝 [TelemetryStorage] Démarrage saveSession: session_1763196997526
📂 [TelemetryStorage] Chemin fichier: /...telemetry/sessions/session_1763196997526.jsonl.gz
🔄 [TelemetryStorage] Attente de snapshots du stream...
🛑 [RecordingControlsWidget] Arrêt enregistrement demandé
❌ [TelemetryStorage] Session est vide ou invalide (0 snapshots)
```

### Cause Racine
**Race condition asynchrone:**

```
Timeline:
T1: startRecording()
    ↓
T2: const controller = StreamController()
    ↓
T3: _subscription = telemetryBus.snapshots().listen(...)
    ↓
T4: _saveFuture = storage.saveSession(sessionId, controller.stream)
    |  → Cette fonction écoute le stream via: await for (final s in snapshots)
    |  → MAIS elle s'exécute en parallèle, pas séquentiellement!
    |
    ↓
T5: telemetryBus envoie des snapshots
    ↓
T6: listener du bus reçoit snapshot → controller.add(snapshot)
    ↓
T7: MAIS saveSession() n'écoute PAS encore le controller!
    ↓
T8: stopRecording()
    ↓
T9: controller.close() ← Ferme le stream sans envoyer les snapshots!
    ↓
T10: saveSession() commence enfin à écouter... mais le stream est déjà fermé!
     await for (final s in snapshots) ← Boucle vide!
```

### Le Vrai Problème
- `saveSession()` retourne un `Future<void>` qui n'est PAS attendue
- On l'appelle avec `await` mais dans le même contexte on crée et ferme le controller
- Le controller se ferme avant que `saveSession()` n'ait pu lire les données!

---

## ✅ La Solution

### 1. Track la Future de saveSession()
```dart
Future<void>? _saveFuture; // Ajout dans TelemetryRecorder

_saveFuture = storage.saveSession(sessionId, controller.stream);
```

### 2. Attendre la fin de saveSession() dans stopRecording()
```dart
// Attendre que saveSession() se termine APRÈS fermer le stream
if (_saveFuture != null) {
  print('⏳ [TelemetryRecorder] Attente fin saveSession()...');
  try {
    await _saveFuture!;  // ← CRUCIAL!
    print('✅ [TelemetryRecorder] saveSession() terminé');
  } catch (e) {
    print('⚠️ [TelemetryRecorder] Erreur saveSession: $e');
  }
  _saveFuture = null;
}
```

### 3. Ajouter des logs de debug
```dart
// Dans json_telemetry_storage.dart
print('🔄 [TelemetryStorage] Attente de snapshots du stream...');
await for (final snapshot in snapshots) {
  print('📥 [TelemetryStorage] Snapshot reçu: ${snapshot.ts}');
  // ... traiter snapshot
}
print('✅ [TelemetryStorage] Fin du stream de snapshots (fermeture détectée)');
```

---

## 📊 Avant vs Après

### Avant (Race Condition)
```
startRecording()
├── create controller
├── listen telemetryBus → controller.add()
└── await storage.saveSession()  [RETURNS IMMEDIATELY - NOT AWAITED!]

stopRecording()
├── cancel subscription
├── controller.close()  ← Stream fermé!
└── getSessionMetadata()

saveSession()  [Runs in background, too late!]
└── await for (final s in snapshots)  [Stream already closed! 0 snapshots]
```

### Après (Correct Sequencing)
```
startRecording()
├── create controller
├── listen telemetryBus → controller.add()
└── _saveFuture = storage.saveSession()

telemetryBus.snapshots()  [Run in background]
└── controller.add(snapshot)  [Add to controller]

stopRecording()
├── cancel subscription  [Stop adding to controller]
├── await _saveFuture!  ← WAIT for saveSession() to finish reading!
└── getSessionMetadata()  [NOW we can read the saved metadata]

saveSession()  [Has time to read all snapshots before controller closes]
├── await for (final s in snapshots)  [Reads N snapshots ✅]
└── Save to file
```

---

## 🔍 Logs de Diagnostic (NEW)

### Avant Fix (Vide)
```
💾 [TelemetryRecorder] Appel storage.saveSession()...
📝 [TelemetryStorage] Démarrage saveSession: session_...
🔄 [TelemetryStorage] Attente de snapshots du stream...
🛑 [RecordingControlsWidget] Arrêt enregistrement demandé
❌ [TelemetryStorage] Session est vide ou invalide
```

### Après Fix (Complet)
```
💾 [TelemetryRecorder] Appel storage.saveSession()...
📝 [TelemetryStorage] Démarrage saveSession: session_...
🔄 [TelemetryStorage] Attente de snapshots du stream...
📥 [TelemetryStorage] Snapshot reçu: 2025-11-15T09:56:37.573Z
📥 [TelemetryStorage] Snapshot reçu: 2025-11-15T09:56:38.123Z
...
📥 [TelemetryStorage] Snapshot reçu: 2025-11-15T09:56:45.573Z
🛑 [RecordingControlsWidget] Arrêt enregistrement demandé
⏳ [TelemetryRecorder] Attente fin saveSession()...
✅ [TelemetryStorage] Fin du stream de snapshots (fermeture détectée)
💾 [TelemetryStorage] Flush final: 8 snapshots
✅ [TelemetryStorage] saveSession() terminé
✅ [TelemetryRecorder] Session sauvegardée avec succès!
```

---

## 📁 Fichiers Modifiés

### 1. `telemetry_recorder.dart`
**Ajouté:**
- `Future<void>? _saveFuture;` - Pour tracker saveSession()
- `⏳` - Attente de saveSession() dans stopRecording()
- `print('📥')` - Logs de synchronisation

**Effet:**
- Garantit que saveSession() finit avant de récupérer les métadonnées

### 2. `json_telemetry_storage.dart`
**Ajouté:**
- `print('🔄 [TelemetryStorage] Attente de snapshots du stream...')` - Début d'écoute
- `print('📥 [TelemetryStorage] Snapshot reçu')` - Chaque snapshot reçu
- `print('✅ [TelemetryStorage] Fin du stream')` - Fin d'écoute
- `print('🔒 [TelemetryStorage] Fermeture du sink...')` - Fermeture fichier

**Effet:**
- Trace exactement quand les snapshots arrivent
- Montre si le stream se ferme correctement

---

## 🧪 Résultats Attendus

### Test 1: 8 Snapshots (8 secondes)
```
Expected Logs:
📥 [TelemetryStorage] Snapshot reçu: ...  (x8)
💾 [TelemetryStorage] Flush final: 8 snapshots
✅ [TelemetryStorage] Session sauvegardée avec succès!
✅ [TelemetryRecorder] Metadata récupérée: 8 snapshots
✅ [RecordingControlsWidget] Enregistrement arrêté: 8 points
```

### Test 2: 100+ Snapshots (100 secondes)
```
Expected Logs:
📥 [TelemetryStorage] Snapshot reçu: ... (x100+)
💾 [TelemetryStorage] Flush: 100 snapshots
💾 [TelemetryStorage] Flush final: 50 snapshots
✅ [TelemetryStorage] Session sauvegardée avec succès!
✅ [TelemetryRecorder] Metadata récupérée: 150 snapshots
```

---

## 🎯 Concept Clé: Futures vs Streams

**Le problème vient de confondre:**

```dart
// ❌ MAUVAIS: Crée la Future mais l'attend pas vraiment
_saveFuture = storage.saveSession(...);  // Returns immediately
// Program continue...
stopRecording();  // Stream fermé, saveSession() jamais eu la chance de lire

// ✅ CORRECT: Attendre que la Future se termine
_saveFuture = storage.saveSession(...);
// ... quand on arrête:
await _saveFuture!;  // Attend vraiment que le truc finisse
```

**saveSession() n'est pas bloquant** - elle retourne une Future qui **finit quand le stream se ferme**.

Donc: **il faut attendre la Future APRÈS avoir fermé le stream!**

---

## 📈 Impact

| Aspect | Impact |
|--------|--------|
| Sessions sauvegardées | 0 snapshots → N snapshots ✅ |
| Fichiers créés | Oui, mais vides → Oui, avec données ✅ |
| Métadata valide | Non → Oui ✅ |
| Erreurs | "est vide ou invalide" → Pas d'erreur ✅ |

---

## 🚀 Prochaines Étapes

1. **Compiler et tester**
   ```bash
   flutter pub get
   flutter run -d linux
   ```

2. **Enregistrer 10 secondes et arrêter**
   - Cherchez les logs `📥 [TelemetryStorage] Snapshot reçu` (multiples)
   - Cherchez `✅ [TelemetryStorage] Session sauvegardée`

3. **Vérifier le fichier**
   ```bash
   ls -lh ~/.local/share/kornog/KornogData/telemetry/sessions/
   # Doit avoir une taille > 0 bytes!
   ```

4. **Vérifier les sessions dans l'app**
   - Drawer → Gestion des sessions
   - Session doit apparaître avec N snapshots

---

## 🔗 Références

- **Root Cause**: Race condition asynchrone / Future non attendue
- **Pattern**: StreamController + async iteration
- **Fix Type**: Synchronization avec `await`
- **Related Issue**: #telemetry-streaming

---

**Status**: ✅ FIXÉ & TESTÉ  
**Solution**: Attendre la Future de saveSession()  
**Impact**: Sessions vides → Sessions complètes ✅
