# 📊 Diagrammes d'Organisation - Kornog App

## 📋 Vue d'ensemble

Tu as maintenant **deux fichiers de diagrammes** pour visualiser l'organisation de ton app :

### 1. **KORNOG_ORGANIZATION.uml** (Format UML/XMI)
- Format XML standard (compatible StarUML, PlantUML, etc.)
- Représentation complète avec packages et dépendances
- Peut être ouvert dans des outils UML professionnels

### 2. **KORNOG_ARCHITECTURE.puml** (Format PlantUML)
- Format texte (facile à modifier et versionner)
- Diagramme coloré et lisible
- Peut être rendu en PNG/SVG avec PlantUML

---

## 🏗️ Architecture en Couches

Ton application suit une architecture **Clean Architecture** en 5 couches :

### LAYER 1: ENTRY POINT (🟥 Rouge)
**Fichiers**: `main.dart`, `app_shell.dart`, `router.dart`, `app_theme.dart`

- Point d'entrée de l'application
- Initialisation du `ProviderScope` (Riverpod)
- Configuration du routage (GoRouter)
- Définition du thème global

**Flux** :
```
main() → App (ConsumerWidget)
  ↓
ProviderScope (Riverpod)
  ↓
MaterialApp.router with theme
  ↓
GoRouter → ShellRoute → HomeShell (bottom nav/rail)
```

---

### LAYER 2: STATE MANAGEMENT (🟦 Bleu-vert)
**Fichiers**: Tous les `*_provider.dart`

#### Providers centralisés:
- `app_providers.dart` → `windSampleProvider`, `telemetryBusProvider`
- `wind_trend_provider.dart` → Analyse des tendances
- `route_plan_provider.dart` → Calcul du plan de route
- `tactics_providers.dart` → Recommandations d'amure
- `polar_providers.dart` → Données de polaires
- `course_providers.dart` → Historique de route

**Responsabilités**:
- Écouter les flux de données (streams)
- Transformer les données avec la logique métier
- Diffuser l'état à toute l'application
- Mémoriser les calculs (caching)

**Pattern**: Riverpod Async Notifier / FutureProvider / StreamProvider

```dart
// Exemple
final windTrendProvider = StreamProvider((ref) {
  final windStream = ref.watch(windSampleProvider);
  return windStream.transform(WindTrendAnalyzer(...));
});
```

---

### LAYER 3: DATA LAYER (🟦 Bleu)
**Fichiers**: `/lib/data/datasources/`

#### Sous-systèmes:

**Telemetry** (Télémétrie):
- `TelemetryBus` (interface abstraite)
- `FakeTelemetryBus` (implémentation simulée pour développement)
- Émet `TelemetryEvent` à intervalles réguliers

**Maps** (Cartes marines):
- `MapRepository` → Accès aux tuiles de cartes
- Modèles: `MapTileSet`, `MapBounds`

**Config** (Configuration):
- `WindTestConfig` → Paramètres de simulation du vent
- Presets: `stable()`, `irregular()`, `backing_left()`, etc.

**Responsabilités**:
- Abstraction des sources de données
- Implémentation réelle ou simulée
- Gestion des fichiers/ressources

---

### LAYER 4: DOMAIN LAYER (🟩 Vert)
**Fichiers**: `/lib/features/charts/domain/`

#### Models (Modèles):
- `Boat` → Caractéristiques du bateau
- `Course` → Route avec waypoints
- `PolarTable` → Tableau de performances
- `GeographicPosition` → Coordonnées lat/long

#### Services (Calculateurs de logique métier):
- `VMCCalculator` → Vitesse vers le mark
- `RoutingCalculator` → Route optimale
- `WindTrendAnalyzer` → Détection backing/veering
- `AdoRefusStrategy` → Recommandations d'amure
- `PolarParser` → Parse les polaires (CSV)
- `PolairePort` → Export/import de données

**Responsabilités**:
- Logique métier indépendante du framework
- Calculs mathématiques et algorithmes
- Transformations de données
- Pas de dépendances Flutter

---

### LAYER 5: PRESENTATION (🟨 Jaune)
**Fichiers**: `/lib/features/*/presentation/`

#### Features (Fonctionnalités):

**Dashboard**
```
DashboardPage (page principale)
├── MetricTile (widgets métriques)
└── Dashboard Provider: selected_metrics
```

**Charts**
```
ChartsPage (cartes et graphiques)
├── CourseCanvas (CustomPainter pour la route)
├── CourseMenu (menu interactif)
└── Providers: route_plan, wind_trend, polar
```

**Analysis**
```
AnalysisPage (analyse détaillée)
├── AnalysisFilters (filtres)
└── Providers: wind_trend
```

**Other**
- AlarmsPage → Alertes
- SettingsPage → Paramètres utilisateur

**Responsabilités**:
- Affichage des données
- Interactions utilisateur
- Mise en forme et animation
- Appels aux Providers

---

## 🔄 Flux de Données (Dataflow)

```
┌─────────────────────────────────────────────────────┐
│  USER ACTION (tap button, scroll, etc.)              │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────┐
│  FEATURE PAGE (e.g., ChartsPage)                     │
│  - watches Provider(s) via ref.watch()               │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────┐
│  PROVIDER (e.g., windTrendProvider)                  │
│  - computes state using domain services             │
│  - returns data stream/future                       │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────┐
│  DOMAIN SERVICES (e.g., WindTrendAnalyzer)           │
│  - pure functions / business logic                  │
│  - uses models (Boat, Course, etc.)                 │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────┐
│  DATA LAYER (FakeTelemetryBus, MapRepository)        │
│  - fetches/generates data                           │
│  - returns models                                    │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────┐
│  RESULT FLOWS BACK TO UI                             │
│  - Provider caches result                           │
│  - Page rebuilds with new data                      │
│  - Widgets display to user                          │
└─────────────────────────────────────────────────────┘
```

---

## 📦 Dépendances Principales

### Directes (code)
```
main.dart
  ↓
app_shell.dart + router.dart + app_theme.dart
  ↓
Feature Pages (DashboardPage, ChartsPage, etc.)
  ↓
Providers (wind_trend_provider, route_plan_provider, etc.)
  ↓
Domain Services (WindTrendAnalyzer, RoutingCalculator, etc.)
  ↓
Data Layer (FakeTelemetryBus, MapRepository, etc.)
  ↓
Configuration (WindTestConfig)
```

### Unidirectionnelles (clean)
- Providers **ne dépendent pas** des Pages
- Domain Services **ne dépendent pas** des Providers
- Data Layer **ne dépend pas** du Domain

---

## 🎯 Exemple: Comment ajouter une nouvelle fonctionnalité

### Scénario: Afficher la "Distance à la destination"

**1. Model** (Domain Layer)
```dart
// lib/features/charts/domain/models/route_metrics.dart
class RouteMetrics {
  double distanceToDestination;
  double estimatedTimeToArrival;
}
```

**2. Service** (Domain Layer)
```dart
// lib/features/charts/domain/services/route_metrics_calculator.dart
class RouteMetricsCalculator {
  RouteMetrics calculate(Boat boat, Course course) {
    // logique de calcul
  }
}
```

**3. Provider** (State Management Layer)
```dart
// lib/features/charts/providers/route_metrics_provider.dart
final routeMetricsProvider = FutureProvider((ref) {
  final boat = ref.watch(boatProvider);
  final course = ref.watch(courseProvider);
  return RouteMetricsCalculator().calculate(boat, course);
});
```

**4. Widget** (Presentation Layer)
```dart
// lib/features/charts/presentation/widgets/route_metrics_display.dart
class RouteMetricsDisplay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(routeMetricsProvider);
    return metrics.when(
      data: (m) => Text("Distance: ${m.distanceToDestination}"),
      loading: () => CircularProgressIndicator(),
      error: (e, _) => Text("Error: $e"),
    );
  }
}
```

**5. Integration** (Feature Page)
```dart
// lib/features/charts/presentation/pages/chart_page.dart
class ChartsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          RouteMetricsDisplay(),  // ← nouveau widget
          CourseCanvas(),
          CourseMenu(),
        ],
      ),
    );
  }
}
```

---

## 📝 Conventions d'Organisation

### Noms de fichiers
- Pages: `*_page.dart`
- Widgets: `*_widget.dart` ou `*_view.dart`
- Providers: `*_provider.dart`
- Services: `*_service.dart` ou `*_calculator.dart`
- Models: `*_model.dart` (domain layer)

### Imports
```dart
// Préférer cette structure
import 'package:kornog/domain/entities/...';      // Models
import 'package:kornog/domain/services/...';      // Services
import 'package:kornog/common/providers/...';     // Global providers
import '../providers/...';                         // Feature providers
import '../presentation/...';                      // UI
```

### Tests
```
test/
├── domain/
│   ├── services/
│   │   ├── wind_trend_analyzer_test.dart
│   │   └── routing_calculator_test.dart
│   └── models/
│       └── boat_test.dart
├── features/
│   ├── charts/
│   │   └── providers/
│   │       └── route_plan_provider_test.dart
└── data/
    └── datasources/
        └── fake_telemetry_bus_test.dart
```

---

## 🚀 Comment utiliser ces diagrammes

### 1. **StarUML** (Desktop App)
- Ouvre `KORNOG_ORGANIZATION.uml` avec StarUML
- Édite et ajoute/modifie la structure
- Exporte en SVG/PNG

### 2. **PlantUML** (En ligne ou CLI)
- Copie le contenu de `KORNOG_ARCHITECTURE.puml`
- Utilise l'éditeur en ligne: https://www.plantuml.com/plantuml/uml/
- Ou génère en local: `plantuml KORNOG_ARCHITECTURE.puml`

### 3. **VS Code**
- Extension: "PlantUML" ou "Draw.io"
- Prévisualise les changements en temps réel

---

## 📚 Références

- **Clean Architecture**: https://blog.cleancoder.com/
- **Riverpod Docs**: https://riverpod.dev/
- **GoRouter**: https://pub.dev/packages/go_router
- **PlantUML Guide**: https://plantuml.com/guide/

---

## ✅ Checklist de Documentation

- ✅ Structure en couches documentée
- ✅ Fichiers d'organisation UML créés
- ✅ Flux de données expliqué
- ✅ Exemple d'ajout de fonctionnalité
- ✅ Conventions d'organisation
- ✅ Références pour approfondir

**Besoin d'aide pour** :
- Ajouter une nouvelle feature ?
- Réorganiser les fichiers ?
- Générer d'autres diagrammes (composants, séquence, etc.) ?

