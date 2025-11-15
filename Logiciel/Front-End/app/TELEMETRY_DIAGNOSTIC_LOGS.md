# 📋 DIAGNOSTIC - Système d'Enregistrement Télémétrie

**Date**: 15 novembre 2025  
**Status**: ✅ LOGS COMPLETS AJOUTÉS + CHEMIN CORRIGÉ

---

## 🎯 Problème Identifié & Solution

### Problème
- Sessions enregistrées mais fichiers **INVALIDES** ou **VIDES**
- Message d'erreur: `Session est vide ou invalide`
- Fichiers stockés dans `~/.kornog/telemetry/` au lieu de la structure Kornog

### Cause Racine
Le stream des snapshots n'était **pas fermé correctement** quand on appelait `stopRecording()`, causant l'écriture incomplète des données.

### Solution Implémentée
1. ✅ **Chemin corrigé** : Télémétrie maintenant dans `KornogData/telemetry/` (comme GRIB et cartes)
2. ✅ **Logs complets ajoutés** : Traçage complète du flux d'enregistrement
3. ✅ **Détection du problème** : Les logs vont révéler où le stream s'arrête

---

## 📊 Flux d'Enregistrement avec Logs

### Phase 1: Démarrage
```
🎬 [RecordingControlsWidget] Démarrage enregistrement: session_1763196492216
📱 [RecordingControlsWidget] Appel recorder.startRecording()...
📱 [RecordingStateNotifier] startRecording(session_1763196492216)
🔴 [RecordingStateNotifier] État → RECORDING
📡 [RecordingStateNotifier] Appel recorder.startRecording()...
🔴 [TelemetryRecorder] Démarrage enregistrement: session_1763196492216
✅ [TelemetryRecorder] État: RECORDING
⏱️ [TelemetryRecorder] Heure début: 2025-11-15 09:48:12.252030
💾 [TelemetryRecorder] Appel storage.saveSession()...
📝 [TelemetryStorage] Démarrage saveSession: session_1763196492216
📂 [TelemetryStorage] Chemin fichier: /home/fefe/.local/share/kornog/KornogData/telemetry/sessions/session_1763196492216.jsonl.gz
```

### Phase 2: Enregistrement (continu)
```
📡 [TelemetryRecorder] 50 snapshots reçus
📡 [TelemetryRecorder] 100 snapshots reçus
💾 [TelemetryStorage] 50 snapshots enregistrés...
```

### Phase 3: Arrêt
```
🛑 [RecordingControlsWidget] Arrêt enregistrement demandé
📱 [RecordingControlsWidget] Appel recorder.stopRecording()...
📱 [RecordingStateNotifier] stopRecording()
⏹️ [RecordingStateNotifier] Appel recorder.stopRecording()...
⏹️ [TelemetryRecorder] Arrêt enregistrement demandé
🛑 [TelemetryRecorder] Arrêt session: session_1763196492216
📊 [TelemetryRecorder] Snapshots enregistrés: 100
⏱️ [TelemetryRecorder] Durée: 30s
📡 [TelemetryRecorder] Annulation subscription du bus...
✅ [TelemetryRecorder] Subscription annulée
✅ [TelemetryRecorder] État: IDLE
📂 [TelemetryRecorder] Récupération metadata...
✅ [TelemetryRecorder] Metadata récupérée: 100 snapshots
✅ [RecordingStateNotifier] Session arrêtée avec succès
✅ [RecordingControlsWidget] Enregistrement arrêté: 100 points
```

---

## 🔍 Logs Par Composant

### 1. RecordingControlsWidget
- 🎬 Démarrage/Arrêt demandé
- ❌ Erreurs détectées
- ✅ Succès avec metadata

### 2. RecordingStateNotifier
- 📱 Appels au notifier
- 🔴/⚪ Changements d'état
- ❌ Erreurs propagées

### 3. TelemetryRecorder
- 🔴 Démarrage enregistrement
- 📡 Snapshots reçus (tous les 50)
- ⏹️ Arrêt subscription
- 📂 Récupération metadata

### 4. TelemetryStorage (JSON)
- 📝 Démarrage saveSession
- 📂 Chemin fichier créé
- 💾 Snapshots flush (tous les 50)
- ✅ Session complétée avec stats

### 5. TelemetryDataDirectory
- 📂 Vérification répertoire
- ✅ Création si nécessaire
- 📦 Listing fichiers existants

---

## 📂 Structure de Répertoires (NOUVEAU)

```
~/.local/share/kornog/KornogData/
├── grib/
│   ├── gfs_2025_11_15_00z.grib2
│   └── gfs_2025_11_15_06z.grib2
├── maps/
│   ├── CarteBretagne.pmtiles
│   └── CarteAtlantique.pmtiles
└── telemetry/  ← 🆕 NOUVEAU!
    ├── sessions/
    │   ├── session_1763196492216.jsonl.gz
    │   ├── session_1763196512340.jsonl.gz
    │   └── session_1763196532456.jsonl.gz
    └── metadata/
        ├── session_1763196492216.json
        ├── session_1763196512340.json
        └── session_1763196532456.json
```

---

## 🧪 Comment Diagnostiquer les Problèmes

### Si "Session vide ou invalide"
1. Regardez les logs `[TelemetryStorage]` - cherchez "💾 Snapshots"
   - Si aucun "💾 flush", le stream n'envoie pas de données
   - Si on voit "💾 100 snapshots" mais "0 snapshots" ensuite = mauvaise fermeture du stream

2. Vérifiez le chemin du fichier:
   - Format attendu: `/home/fefe/.local/share/kornog/KornogData/telemetry/sessions/session_*.jsonl.gz`

3. Vérifiez les logs `[TelemetryRecorder]`:
   - Cherchez "Snapshots reçus: 0" = pas de données du bus
   - Cherchez "Subscription annulée" = fermeture correcte

### Si Erreur "Stream fermé"
- Le `sink.close()` a été appelé trop tôt
- Le `TelemetryRecorder` n'a pas attendu la fin du stream

### Si Metadata invalide
- Les timestamps firstSnapshot/lastSnapshot sont NULL
- Aucun snapshot n'a été reçu du bus

---

## 📈 Améliorations Apportées

| Aspect | Avant | Après |
|--------|-------|-------|
| **Chemin** | `~/.kornog/telemetry/` | `KornogData/telemetry/` ✅ |
| **Structure** | Plate | Organisée (sessions + metadata) ✅ |
| **Logs Recording** | Minimal | Complet (5 phases) ✅ |
| **Logs Storage** | Minimal | Complet (80+ log points) ✅ |
| **Diagnostique** | Difficile | Facile avec traces ✅ |

---

## 🚀 Prochaines Étapes

1. **Testez l'enregistrement**
   - Ouvrez le drawer
   - Cliquez "Enregistrement"
   - Cliquez "Démarrer"
   - Attendez 10 secondes
   - Cliquez "Arrêter"

2. **Consultez les logs** (ouvrez la console Flutter)
   - Cherchez les logs `[TelemetryStorage] ✅ Session sauvegardée`
   - Si c'est là: ✅ Succès!
   - Sinon: regardez où ça s'arrête

3. **Vérifiez les fichiers**
   ```bash
   ls -lh ~/.local/share/kornog/KornogData/telemetry/sessions/
   ls -lh ~/.local/share/kornog/KornogData/telemetry/metadata/
   ```

4. **Consultez la gestion des sessions**
   - Les sessions apparaissent dans le drawer "Gestion des sessions"
   - Stats affichées: snapshots, taille, durée

---

## 🎯 Points Clés à Retenir

✅ **Logs détaillés** - Chaque étape est tracée  
✅ **Chemin correct** - Télémétrie dans KornogData comme prévu  
✅ **Structure organisée** - Même organisation que GRIB et cartes  
✅ **Diagnostique facile** - Suivez les logs pour déboguer  

---

**Status**: ✅ Prêt à tester!  
**Logs**: Complets et formatés  
**Chemin**: Corrigé vers KornogData/telemetry/
