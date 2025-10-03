# 🌊 Architecture Simplifiée du Vent - Kornog

## 📋 Fichiers de Simulation du Vent (Nettoyés)

### ✅ **Fichiers Actifs (Utilisés)**

#### 1. **Configuration Simple**
```
📁 /lib/config/wind_test_config.dart
```
**Rôle** : Configuration principale pour les tests de vent
**Usage** : Modifiez ce fichier pour changer le comportement du vent
**Paramètres** :
- `mode` : 'stable', 'irregular', 'backing_left', 'veering_right', 'chaotic'
- `baseDirection` : Direction de base du vent (degrés)
- `baseSpeed` : Vitesse de base (nœuds)
- `noiseMagnitude` : Intensité du bruit aléatoire
- `rotationRate` : Vitesse de rotation pour modes backing/veering

#### 2. **Génération de Données**
```
📁 /lib/data/datasources/telemetry/fake_telemetry_bus.dart
```
**Rôle** : Bus principal de télémétrie simulée
**Usage** : Utilise `WindTestConfig` pour générer TWD, TWS, TWA, etc.
**Ne pas modifier** : Sauf pour ajuster la logique de simulation

#### 3. **Analyse des Tendances**
```
📁 /lib/features/charts/domain/services/wind_trend_analyzer.dart
📁 /lib/features/charts/providers/wind_trend_provider.dart
```
**Rôle** : Détection des tendances de vent (backing/veering)
**Usage** : Utilisé par l'interface graphique pour afficher les analyses

---

## 🗑️ **Fichiers Supprimés (Redondants)**

- ❌ `wind_simulator.dart` - Simulateur complexe non utilisé
- ❌ `wind_simulator_config.dart` - Configuration complexe doublonnée
- ❌ `wind_test_example.dart` - Exemple créant de la confusion
- ❌ `WIND_CONFIG_README.md` - Documentation obsolète

---

## 🔧 **Comment Modifier le Vent pour vos Tests**

### Étape 1: Ouvrir le fichier de configuration
```bash
code lib/config/wind_test_config.dart
```

### Étape 2: Modifier les paramètres
```dart
class WindTestConfig {
  static const String mode = 'backing_left';  // ← Changez ça
  static const double baseDirection = 270.0;  // ← Et ça
  static const double baseSpeed = 12.0;       // ← Et ça
  // ...
}
```

### Étape 3: Redémarrer l'application
Le nouveau vent est automatiquement pris en compte.

---

## 📊 **Modes de Vent Disponibles**

| Mode | Comportement |
|------|-------------|
| `'stable'` | Vent stable avec petit bruit aléatoire |
| `'irregular'` | Vent avec variations aléatoires |
| `'backing_left'` | **VOTRE MODE ACTUEL** - Vent qui tourne vers la gauche |
| `'veering_right'` | Vent qui tourne vers la droite |
| `'chaotic'` | Vent très instable pour tests extrêmes |

---

## 🎯 **Architecture Simplifiée**

```
WindTestConfig (config)
        ↓
FakeTelemetryBus (génération)
        ↓
windSampleProvider (distribution)
        ↓
WindTrendAnalyzer (analyse)
        ↓
Interface utilisateur (affichage)
```

**Avantages** :
- ✅ Un seul fichier à modifier (`wind_test_config.dart`)
- ✅ Plus de confusion entre multiples systèmes
- ✅ Architecture claire et simple
- ✅ Facilement extensible

---

## 🚀 **Prochaines Étapes**

1. **Pour tester** : Modifiez `WindTestConfig.mode`
2. **Pour étendre** : Ajoutez des paramètres dans `WindTestConfig`
3. **Pour une vraie source** : Remplacez `FakeTelemetryBus` par une source NMEA réelle

---

*Architecture simplifiée le $(date) - Plus de confusion, juste efficacité !*