# Configuration simple du vent pour les tests

## 🎯 Utilisation rapide

### 1. Modifier la configuration
Éditez le fichier `/lib/config/wind_test_config.dart` :

```dart
class WindTestConfig {
  /// Mode de simulation
  static const String mode = 'irregular';  // ← Changez ici
  
  /// Direction de base du vent (degrés)
  static const double baseDirection = 315.0;  // ← Nord-Ouest
  
  /// Vitesse de base du vent (nœuds)  
  static const double baseSpeed = 12.0;  // ← 12 nœuds
  
  /// Bruit aléatoire (degrés)
  static const double noiseMagnitude = 4.0;  // ← ±4°
  
  /// Vitesse de bascule (degrés/minute)
  static const double rotationRate = 0.0;  // ← Pas de bascule
  
  /// Oscillations (degrés)
  static const double oscillationAmplitude = 10.0;  // ← ±10°
}
```

### 2. Redémarrer l'app
```bash
flutter run
```

C'est tout ! Le nouveau vent est automatiquement appliqué.

## 📋 Modes disponibles

| Mode | Description | Utilisation |
|------|-------------|-------------|
| `'stable'` | Vent très constant | Tests débutants |
| `'irregular'` | Vent avec oscillations | Tests réalistes |  
| `'backing_left'` | Bascule vers la gauche | Tests tactiques |
| `'veering_right'` | Bascule vers la droite | Tests tactiques |
| `'chaotic'` | Vent très perturbé | Tests conditions difficiles |

## 🎛️ Paramètres

### Direction (0-360°)
- `0°` = Nord
- `90°` = Est  
- `180°` = Sud
- `270°` = Ouest
- `315°` = Nord-Ouest (défaut régate)

### Vitesse (nœuds)
- `8-10` = Vent léger
- `12-15` = Vent modéré (régate)
- `18-25` = Vent fort

### Bruit aléatoire (degrés)
- `0-1` = Très stable
- `2-5` = Réaliste
- `6+` = Très irrégulier

### Bascule (degrés/minute)
- `0` = Pas de bascule
- `2-3` = Bascule lente
- `5+` = Bascule rapide
- **Négatif** = vers la gauche
- **Positif** = vers la droite

## 🚀 Configurations prêtes à l'emploi

### Vent stable pour débutant
```dart
static const String mode = 'stable';
static const double baseDirection = 270.0;  // Ouest
static const double baseSpeed = 10.0;
static const double noiseMagnitude = 0.5;
static const double rotationRate = 0.0;
static const double oscillationAmplitude = 1.0;
```

### Conditions de régate réalistes  
```dart
static const String mode = 'irregular';
static const double baseDirection = 315.0;  // Nord-Ouest
static const double baseSpeed = 12.0;
static const double noiseMagnitude = 4.0;
static const double rotationRate = 0.0;
static const double oscillationAmplitude = 10.0;
```

### Bascule tactique vers la droite
```dart
static const String mode = 'veering_right';
static const double baseDirection = 310.0;
static const double baseSpeed = 14.0;
static const double noiseMagnitude = 2.5;
static const double rotationRate = 3.0;  // Bascule rapide
static const double oscillationAmplitude = 5.0;
```

### Bascule tactique vers la gauche
```dart
static const String mode = 'backing_left';
static const double baseDirection = 320.0;
static const double baseSpeed = 14.0;
static const double noiseMagnitude = 2.5;
static const double rotationRate = -3.0;  // Négatif = gauche
static const double oscillationAmplitude = 5.0;
```

### Vent fort et chaotique
```dart
static const String mode = 'chaotic';
static const double baseDirection = 225.0;  // Sud-Ouest
static const double baseSpeed = 18.0;
static const double noiseMagnitude = 6.0;
static const double rotationRate = 1.5;
static const double oscillationAmplitude = 15.0;
```

## 🔍 Vérifier la configuration

Pour voir la configuration actuelle en temps réel, ajoutez ce widget à votre écran :

```dart
import 'package:kornog/examples/wind_test_example.dart';

// Dans votre build():
WindTestDisplay()
```

## 📂 Structure des fichiers

```
lib/
├── config/
│   └── wind_test_config.dart      ← Configuration à modifier
├── data/datasources/telemetry/
│   └── fake_telemetry_bus.dart    ← Utilise automatiquement la config
└── examples/
    └── wind_test_example.dart     ← Widget d'affichage
```

✅ **C'est tout ! Votre vent est maintenant configurable facilement pour tous vos tests.**