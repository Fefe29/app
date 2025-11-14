## ✅ INTÉGRATION TÉLÉMÉTRIE DANS ANALYSIS_PAGE

### Résumé de l'implémentation

La page d'analyse (`analysis_page`) a été refactorisée pour intégrer directement les contrôles de télémétrie avec un système d'onglets.

### Structure des onglets

#### 1️⃣ **Onglet "📈 Vent"** 
- Graphiques des données de vent (TWD, TWA, TWS)
- Diagrammes polaires avec sélection de force de vent
- Vitesse du bateau
- Filtrages via le drawer latéral

#### 2️⃣ **Onglet "🎯 Données"**
- Affichage de la dernière session disponible
- Statistiques : vitesse moyenne/max, vent moyen, nombre de points
- Tableau de données en temps réel (Temps, SOG, HDG, TWS, TWD)
- Scroll horizontal pour explorer les colonnes

#### 3️⃣ **Onglet "⏱️ Enregistrement"**
- Indicateur d'état de l'enregistrement (Inactif / 🔴 Enregistrement / ⏸️ Pause / ❌ Erreur)
- **Boutons de contrôle:**
  - `Démarrer` (rouge) - Lance nouvel enregistrement avec session_timestamp
  - `Arrêter` (orange) - Termine l'enregistrement en cours
  - `Pause` (gris) - Met en pause temporairement
  - `Reprendre` (vert) - Reprend après pause
- Instructions d'utilisation
- Confirmations visuelles via SnackBar

#### 4️⃣ **Onglet "📂 Gestion"**
- Liste complète des sessions enregistrées
- Pour chaque session :
  - Nom du fichier (session_timestamp)
  - Nombre de points capturés
  - Taille du fichier en KB
- **Menu contextuel** pour chaque session :
  - `Exporter CSV` - Format tabulaire pour Excel/Python
  - `Exporter JSON` - Format brut avec toutes les métadonnées
  - `Supprimer` - Suppression permanente

### Fichiers créés/modifiés

#### ✨ Nouveaux fichiers

**`lib/features/analysis/presentation/widgets/telemetry_widgets.dart`** (350+ lignes)
- `RecordingControlsWidget` - Contrôles start/stop/pause
- `SessionManagementWidget` - Gestion des sessions (lister, supprimer, exporter)
- `DataViewerWidget` - Affichage des données de session
- `_StatusIndicator` - Indicateur coloré de l'état d'enregistrement
- `_StatChip` - Tuiles de statistiques

#### 🔄 Fichiers modifiés

**`lib/features/analysis/presentation/pages/analysis_page.dart`**
- Restructurée avec `DefaultTabController`
- 4 onglets avec TabBar
- Drawer pour filtres d'analyse (conservé fonctionnement existant)
- Classes locales : `_WindAnalysisTab`, `_CurrentSessionDataTab`, `_RecordingControlsTab`, `_SessionManagementTab`

**`lib/app/router.dart`**
- Retrait de la route `/analysis/advanced` (intégrée dans `/analysis`)
- Suppression import `advanced_analysis_page.dart`

### Architecture Riverpod

#### Providers utilisés

```dart
// État
recordingStateProvider          // État d'enregistrement (idle/recording/paused/error)
analysisFiltersProvider         // Filtres de l'analyse (TWD, TWA, TWS, etc.)

// Données
sessionsListProvider            // Liste toutes les sessions
sessionDataProvider(sessionId)  // Charge les données d'une session
sessionStatsProvider(sessionId) // Stats d'une session (avg speed, max, etc.)

// Actions
sessionManagementProvider       // Actions : delete, export, cleanup
```

### Contrôles utilisateur

#### Démarrer un enregistrement
```
1. Cliquer sur "Démarrer" dans l'onglet "⏱️ Enregistrement"
2. L'app crée automatiquement : session_<timestamp>
3. Les données du TelemetryBus sont capturées en continu
4. Confirmations affichées via SnackBar
```

#### Gérer les sessions
```
1. Aller à l'onglet "📂 Gestion"
2. Sélectionner une session
3. Menu contextuel : Export / Supprimer
4. Sessions stockées en : ~/.kornog/telemetry/
```

#### Afficher les données
```
1. Onglet "🎯 Données" affiche automatiquement la dernière session
2. Scroll horizontal pour voir tous les paramètres
3. Stats résumées en haut (vitesse, vent, points)
```

### Intégration avec l'existant

✅ Conservation complète de la page d'analyse originale  
✅ Filtres TWD/TWA/TWS/BoatSpeed/Polars fonctionnels  
✅ Drawer latéral pour configuration  
✅ Graphiques et polaires affichés dans l'onglet "Vent"  
✅ Pas de breaking changes, extensible

### Validation

- ✅ flutter analyze : Aucune erreur dans les fichiers télémétrie
- ✅ flutter pub get : Toutes les dépendances résolues
- ✅ Imports corrects et types validés
- ✅ Providers Riverpod 3.0 utilisés correctement

### Prochaines étapes optionnelles

1. **Graphiques temps réel** : Ajouter des charts d'évolution lors de l'enregistrement
2. **Comparaison multi-sessions** : Onglet pour croiser données de plusieurs sessions
3. **Export personnalisé** : Permettre sélection des colonnes à exporter
4. **Filtrage avancé** : Filtrer par date/durée/nombre de points
5. **Statistiques** : Ajouter calculs (moyenne mobile, gust factor, etc.)

### Notes d'implémentation

- Les widgets sont **stateless/consumer** pour réactivité Riverpod
- L'export utilise `TelemetryStorage.exportSession()` (CSV/JSON)
- Les suppressions invalident les caches automatiquement
- SnackBar pour feedback utilisateur immédiat
- Design cohérent avec Material Design 3
