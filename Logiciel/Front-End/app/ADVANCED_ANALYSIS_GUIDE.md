# 🎯 Advanced Analysis Center - Guide Complet

## Vue d'ensemble

La **fenêtre d'analyse avancée** est ton centre de contrôle complet pour :
- ✅ **Enregistrer en temps réel** : Démarrer/arrêter des sessions avec contrôles précis
- ✅ **Gérer les sessions** : Lister, supprimer, exporter toutes tes données
- ✅ **Analyser la session en cours** : Voir les données en direct pendant l'enregistrement
- ✅ **Analyser des sessions précédentes** : Charger n'importe quelle session sauvegardée
- ✅ **Comparer plusieurs sessions** : Croiser les données pour le "débriefing complet"

## 🚀 Accès rapide

```dart
// Dans ton app, navigue vers :
context.go('/analysis/advanced');

// Ou depuis n'importe quel widget :
ref.read(routerProvider).push('/analysis/advanced');
```

## 🎮 Zones de la fenêtre

### 1️⃣ Panneau de Contrôle (Haut)

**État de l'enregistrement**
- 🟢 Arrêté (gris)
- 🔴 Enregistrement en cours (rouge)
- 🟠 En pause (orange)
- ❌ Erreur (rouge foncé)

**Contrôles**

| Contrôle | État | Action |
|----------|------|--------|
| Nom de session | `Arrêté` | Saisir le nom de la nouvelle session |
| ▶ Démarrer | `Arrêté` | Lancer un nouvel enregistrement |
| ⏸ Pause | `Enregistrement` | Mettre en pause |
| ▶ Reprendre | `Pause` | Continuer l'enregistrement |
| ⏹ Arrêter | `Enregistrement/Pause` | Arrêter et sauvegarder |

**Stats en direct**
```
🔴 Enregistrement en cours...
✓ 1,245 points  ✓ 42s
```

### 2️⃣ Sélecteur de Sessions (Gauche)

Liste toutes les sessions disponibles :
- **Sessions sauvegardées** : Affichées avec taille et nombre de points
- **Sélection** : Cliquer pour charger dans le visionneur
- **Actions par session** :
  - `📊 CSV` : Exporter en CSV
  - `📄 JSON` : Exporter en JSON
  - `🗑️ Supprimer` : Supprimer (avec confirmation)

Exemple d'affichage :
```
regatta_2025_11_14_race1
├ 8,432 pts • 2.3MB
└ [📊] [📄] [🗑️]

session_1731513600000
├ 3,156 pts • 847KB
└ [📊] [📄] [🗑️]
```

### 3️⃣ Visionneur de Données (Droite)

Affiche les données de la session sélectionnée.

**Barre de stats**
```
┌─────────────────────────────────────────────────┐
│ 📊 Vitesse moy.  📈 Max       📉 Min            │
│     12.4 kn      15.8 kn      8.3 kn             │
│ 💨 Vent  🔢 Points                              │
│ 10.2 kn    8,432                                 │
└─────────────────────────────────────────────────┘
```

**Tableau de données**
```
Temps     │ SOG    │ HDG  │ COG  │ TWD  │ TWA  │ TWS   │ AWA  │ AWS
06:15:32  │ 12.4   │ 45   │ 48   │ 180  │ 135  │ 10.2  │ 120  │ 9.8
06:15:33  │ 12.3   │ 45   │ 48   │ 181  │ 136  │ 10.1  │ 121  │ 9.7
06:15:34  │ 12.5   │ 46   │ 49   │ 180  │ 134  │ 10.3  │ 119  │ 9.9
```

## 💡 Cas d'usage

### Cas 1️⃣ : Enregistrer une nouvelle course

```
1. Cliquer sur "Nom session"
   └─ Taper : "regatta_20251114_race2"

2. Cliquer "▶ Démarrer"
   └─ Affiche "🔴 Enregistrement en cours..."

3. Faire ta course...
   └─ Voir les stats en direct : 2,456 pts • 487s

4. Cliquer "⏹ Arrêter"
   └─ Session sauvegardée automatiquement
   └─ Affiche "✅ Sauvegardée: 2,456 points"

5. Nouvelle session apparaît dans la liste
```

### Cas 2️⃣ : Analyser une session précédente

```
1. Regarder la liste des sessions (gauche)

2. Cliquer sur "regatta_20251114_race1"
   └─ Données chargées dans le tableau

3. Voir les stats calculées
   ✓ Vitesse moyenne, max, min
   ✓ Vent moyen
   ✓ Nombre total de points

4. Scroll le tableau pour explorer tous les points
```

### Cas 3️⃣ : Exporter pour analyse externe

```
1. Cliquer sur la session à exporter

2. Cliquer sur [📊] ou [📄]
   ├─ CSV : Format tableur (Excel, Google Sheets)
   └─ JSON : Format structuré (scripts, dashboards)

3. Fichier sauvegardé dans :
   └─ /sdcard/Download/

4. Utiliser dans ton outil préféré
   └─ Excel : Graphiques, formules
   └─ Python : Analyse avancée
   └─ Tableau Public : Dashboard interactif
```

### Cas 4️⃣ : Débriefing complet (Comparaison multi-sessions)

**Scenario** : Comparer Run 1 vs Run 2 de la même course

```
1. Charger Run 1 ("race1_run1")
   └─ Note les vitesses moyennes, vent, etc.

2. Charger Run 2 ("race1_run2")
   └─ Comparer manuellement les stats

3. Exporter les deux en CSV

4. Fusionner dans Excel pour visualiser :
   └─ Graphique : SOG Run1 vs SOG Run2
   └─ Graphique : Wind Run1 vs Wind Run2
   └─ Tableau croisé : Conditions identiques?

5. Analyser les différences :
   ✓ Réglages changés?
   ✓ Conditions météo?
   ✓ Erreur humaine?
   ✓ Performance bateau?
```

**Future Feature** : Comparaison visuelle intégrée dans l'app
```
Tab "Compare"
├─ Sélectionner Session A : race1_run1
├─ Sélectionner Session B : race1_run2
└─ Graphique superposé montrant les deux courbes
```

### Cas 5️⃣ : Nettoyer les vieilles sessions

```
1. Cliquer sur [🗑️] pour chaque session ancienne
   └─ Confirmation avant suppression

2. Ou dans le menu (futur) :
   └─ "Nettoyer les sessions >30 jours"
   └─ Libère automatiquement l'espace disque

Avant :  └─ Sessions: 125 MB
Après :  └─ Sessions: 42 MB
```

## 📊 Formats de données

### CSV (Tableur)
```csv
timestamp,nav.sog,nav.hdg,nav.cog,wind.twd,wind.twa,wind.tws,wind.awa,wind.aws
2025-11-14T06:15:32Z,12.4,45,48,180,135,10.2,120,9.8
2025-11-14T06:15:33Z,12.3,45,48,181,136,10.1,121,9.7
2025-11-14T06:15:34Z,12.5,46,49,180,134,10.3,119,9.9
```

### JSON (Structuré)
```json
{
  "sessionId": "race1_run1",
  "snapshots": [
    {
      "ts": "2025-11-14T06:15:32Z",
      "metrics": {
        "nav.sog": { "value": 12.4, "unit": "kn" },
        "wind.tws": { "value": 10.2, "unit": "kn" }
      }
    }
  ]
}
```

## ⚙️ Architecture technique

### State Management (Riverpod)

```dart
// 📍 État global
recordingStateProvider     // Idle, Recording, Paused, Error
currentlyViewedSessionProvider  // Session actuellement vue

// 📊 Données
sessionsListProvider       // Liste toutes les sessions
sessionDataProvider(id)    // Données complètes d'une session
sessionStatsProvider(id)   // Stats (moyennes, min, max)
```

### Cycle de vie d'une session

```
1. startRecording()
   └─ État: Recording
   └─ Snapshots collectés du TelemetryBus

2. [Pendant l'enregistrement]
   └─ onProgress() callback
   └─ Snapshots compressés en GZIP

3. stopRecording()
   └─ État: Idle
   └─ Fichier .jsonl.gz sauvegardé
   └─ Métadonnées indexées

4. loadSession()
   └─ Décompression GZIP
   └─ Parse JSON Lines
   └─ Calcul des stats
```

### Stockage physique

```
~/.kornog/telemetry/
├─ sessions/
│  ├─ race1_run1.jsonl.gz      (1.2 MB)
│  ├─ race1_run2.jsonl.gz      (1.3 MB)
│  └─ session_1731513600000.jsonl.gz
└─ metadata/
   ├─ race1_run1.json          (2 KB)
   ├─ race1_run2.json
   └─ session_1731513600000.json
```

## 🐛 Dépannage

| Problème | Cause | Solution |
|----------|-------|----------|
| Enregistrement ne démarre pas | Permission fichier | Accorder permission stockage dans settings |
| Session vide | Bateau pas connecté | Vérifier TelemetryBus connecté |
| Export échoue | Chemin invalide | Vérifier `/sdcard/Download/` existe |
| Charge lente | Gros fichier | Sessions >100 MB? Diviser en sessions plus petites |

## 🎯 Prochaines étapes

### Phase 2 : Graphiques intégrés
```
Tab "Graphes"
├─ SOG au fil du temps
├─ Wind pattern
├─ Polaire (TWS vs Boat Speed)
└─ Heatmap conditions
```

### Phase 3 : Comparaison multi-sessions
```
Tab "Compare"
├─ Sélectionner 2-3 sessions
├─ Overlay des courbes SOG
├─ Statistiques différentielles
└─ Export rapport PDF
```

### Phase 4 : Stockage avancé
```
Parquet format
├─ Compression 80% (vs JSON 70%)
├─ Queries SQL natif
├─ Perfect pour datasets volumineux
└─ Migration automatique depuis JSON
```

## 📞 Support

Questions ou bugs?
1. Check ADVANCED_ANALYSIS_GUIDE.md (ce fichier)
2. Check telemetry_storage_providers.dart pour voir tous les providers
3. Check test/telemetry_storage_test.dart pour des exemples

---

**Créé** : 2025-11-14  
**Version** : 1.0  
**Status** : ✅ Production ready  
