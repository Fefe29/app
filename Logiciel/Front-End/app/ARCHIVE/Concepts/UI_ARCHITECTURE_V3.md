# 🏗️ ARCHITECTURE UI V3.0 - INTERFACE SIMPLIFIÉE

## Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────┐
│                    📊 ANALYSE                               │
│  ☰  [Drawer]           [⏱️ Enregistrement] [📂 Gestion]    │
└─────────────────────────────────────────────────────────────┘
│                                                               │
│  [Main Content Area - ListView]                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Graphiques filtrés selon sélection du Drawer        │    │
│  │ - Direction du vent (TWD)                           │    │
│  │ - Angle du vent (TWA)                               │    │
│  │ - Vitesse du vent (TWS)                             │    │
│  │ - Vitesse du bateau                                 │    │
│  │ - Polaires J80 avec sélecteur force               │    │
│  │                                                      │    │
│  │ [Stats clés dernière session]                       │    │
│  │ ┌──────────────┬──────────────┐                      │    │
│  │ │ Vitesse MAX  │ Vitesse MOY  │                      │    │
│  │ │ XX knots     │ XX knots     │                      │    │
│  │ ├──────────────┼──────────────┤                      │    │
│  │ │ Vent MOY     │ Points       │                      │    │
│  │ │ XX knots     │ XXX          │                      │    │
│  │ └──────────────┴──────────────┘                      │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Composants Détaillés

### 📱 AnalysisPage (Principale)

```
AnalysisPage
├── Scaffold
│   ├── AppBar
│   │   ├── Title: "📊 Analyse"
│   │   └── Actions: [⏱️ Enregistrement] [📂 Gestion]
│   │
│   ├── Drawer (Latéral - Sélection des données)
│   │   └── FilteredCheckboxes (Riverpod state management)
│   │       ├── ✅ TWD (Direction du vent)
│   │       ├── ✅ TWA (Angle du vent)
│   │       ├── ✅ TWS (Vitesse du vent)
│   │       ├── ✅ Boat Speed
│   │       └── ✅ Polaires J80
│   │
│   └── Body: _AnalysisTab()
│       └── ListView (Contenu principal)
│           ├── SingleWindMetricChart (TWD)
│           ├── SingleWindMetricChart (TWA)
│           ├── SingleWindMetricChart (TWS)
│           ├── BoatSpeedChart
│           ├── PolarChart (J80)
│           └── SessionStatsWidget (Stats clés)
```

### 🪟 Fenêtre Enregistrement (Dialog)

```
showDialog()
└── AlertDialog
    ├── Title: "⏱️ Enregistrement"
    ├── Content: Column
    │   ├── RecordingControlsWidget
    │   │   ├── StartButton
    │   │   ├── PauseButton
    │   │   ├── StopButton
    │   │   └── StatusIndicator (Riverpod)
    │   │
    │   └── InstructionsCard (ScrollView)
    │       └── Instructions texte
    │
    └── Actions: [Fermer]
```

### 🪟 Fenêtre Gestion (Dialog)

```
showDialog()
└── AlertDialog
    ├── Title: "📂 Gestion des sessions"
    ├── Content: SessionManagementWidget
    │   ├── SessionList (Riverpod)
    │   │   └── SessionTile x N
    │   │       ├── Session name
    │   │       ├── Timestamp
    │   │       ├── Stats summary
    │   │       ├── [Export] Button
    │   │       └── [Delete] Button
    │   │
    │   └── Export dialog (nested)
    │
    └── Actions: [Fermer]
```

## État Riverpod (State Management)

```
📦 State Management
├── analysisFiltersProvider (NotifierProvider)
│   └── Stocke sélection Drawer (twd, twa, tws, boatSpeed, polars)
│
├── recordingStateProvider (NotifierProvider)
│   └── Stocke état enregistrement (idle, recording, paused, error)
│
├── sessionsListProvider (FutureProvider)
│   └── Liste des sessions sauvegardées
│
└── sessionStatsProvider(sessionId) (FutureProvider)
    └── Stats d'une session (max speed, avg speed, etc.)
```

## 🔄 Flux d'Interaction

### Workflow Affichage
```
1. User ouvre AnalysisPage
2. Drawer affiche options (défaut: tous cochés)
3. Graphiques affichés selon sélection
4. User coche/décoche une option
5. analysisFiltersProvider notifie _AnalysisTab
6. ListView reconstruit avec/sans le graphique
```

### Workflow Enregistrement
```
1. User clique bouton ⏱️ Enregistrement
2. showDialog() affiche RecordingControlsWidget
3. User clique "Démarrer"
4. recordingStateProvider → recording
5. StatusIndicator change (🔴 Recording)
6. User clique "Arrêter"
7. recordingStateProvider → idle
8. Session sauvegardée dans ~/.kornog/telemetry/
```

### Workflow Gestion
```
1. User clique bouton 📂 Gestion
2. showDialog() charge SessionManagementWidget
3. sessionsListProvider charge les sessions
4. SessionTile affichées
5. User clique Export/Delete
6. sessionManagementProvider effectue l'action
```

## 🎨 Avantages V3.0

| Aspect | V2.1 (3 Onglets) | V3.0 (1 Onglet + Dialogs) |
|--------|-----------------|-------------------------|
| **Espace** | Fragmenté sur 3 onglets | Concentré, plus lisible |
| **Navigation** | Glissements entre onglets | Menu + Dialogs (focus) |
| **Encombrement** | Plusieurs contrôles visibles | Propre, épuré |
| **Flexibilité** | Rigide (3 onglets fixes) | Flexible (drawer + actions) |
| **Focus utilisateur** | Dispersé | Sur les données principales |
| **Gestion mémoire** | 3 widgets toujours en RAM | Dialogs chargées à la demande |

## 📂 Fichiers Modifiés

- `lib/features/analysis/presentation/pages/analysis_page.dart`
  - Suppression de `DefaultTabController` (onglets)
  - Ajout de `_showRecordingDialog()` 
  - Ajout de `_showSessionManagementDialog()`
  - Conservé `_AnalysisTab` avec ListView/Drawer
  
- `TELEMETRY_QUICK_START.md`
  - Mise à jour documentation (V3.0)
  - Guide d'utilisation simple

## 🚀 Prochaines Optimisations Possibles

- [ ] Comparaison multi-sessions dans dialogs
- [ ] Filtres temps réel (slider du nombre de points)
- [ ] Onglets dynamiques en drawer (show/hide)
- [ ] Export personnalisé (colonnes à exporter)
- [ ] Favoris sessions (pin/star)

---

**Status**: ✅ Implémentée & Testée
**Erreurs de compilation**: 0
**Architecture**: Clean, modulaire, maintenable
