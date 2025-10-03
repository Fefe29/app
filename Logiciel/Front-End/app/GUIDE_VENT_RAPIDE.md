# 🌊 Guide Rapide - Configuration du Vent

## 🎯 Utilisation Ultra-Simple

### 1️⃣ **Changer de preset rapidement**
Ouvrez `lib/config/wind_test_config.dart` et modifiez cette ligne :

```dart
static final WindTestConfig current = WindTestConfig.backingLeft();
```

### 2️⃣ **Presets disponibles**

| Preset | Description | Usage |
|--------|-------------|--------|
| `stable()` | 🟢 Vent constant | Tests d'algorithmes de base |
| `irregular()` | 🟡 Vent réaliste | Conditions de régate standard |
| `backingLeft()` | 🔵 Bascule ← gauche | Favorable bord bâbord |
| `veeringRight()` | 🔴 Bascule → droite | Favorable bord tribord |
| `chaotic()` | ⚡ Vent violent | Conditions extrêmes |
| `fastBackingLeft()` | 🎯 Bascule rapide ← | Avantage tactique immédiat |
| `slowVeeringRight()` | 🎯 Bascule lente → | Évolution progressive |
| `oscillating()` | 🌪️ Oscillations | Vent cyclique |

### 3️⃣ **Personnalisation rapide**

```dart
// Bascule plus rapide vers la gauche
WindTestConfig.current = WindTestConfig.backingLeft(
  rotationRate: -6.0,  // -6°/min au lieu de -3°/min
);

// Vent plus fort avec moins de bruit
WindTestConfig.current = WindTestConfig.backingLeft(
  baseSpeed: 18.0,        // 18 nœuds au lieu de 14
  noiseMagnitude: 1.0,    // Moins de variations aléatoires
);

// Configuration complète personnalisée
WindTestConfig.current = WindTestConfig.backingLeft(
  baseDirection: 350.0,      // Direction de base
  baseSpeed: 16.0,           // Vitesse en nœuds
  rotationRate: -4.5,        // Vitesse de bascule (°/min)
  noiseMagnitude: 2.0,       // Bruit aléatoire (°)
  oscillationAmplitude: 5.0, // Amplitude oscillations (°)
  updateIntervalMs: 800,     // Fréquence de mise à jour (ms)
);
```

## 🔧 **Paramètres Expliqués**

### `rotationRate` (vitesse de bascule)
- **Négatif** : Bascule vers la **gauche** (favorable bâbord)
- **Positif** : Bascule vers la **droite** (favorable tribord)
- **0** : Pas de bascule
- **Valeurs typiques** : -6.0 à +6.0 (degrés par minute)

### `baseDirection` (direction de base)
- **0°** : Nord
- **90°** : Est  
- **180°** : Sud
- **270°** : Ouest
- **315°** : Nord-Ouest (typique en régate)

### `noiseMagnitude` (bruit aléatoire)
- **0-1** : Vent très stable
- **2-4** : Variations réalistes
- **5+** : Vent perturbé

### `oscillationAmplitude` (oscillations)
- **0-5** : Petites variations
- **5-15** : Oscillations modérées
- **20+** : Grandes variations

## 🚀 **Actions Rapides**

### Tester une bascule tactique gauche
```dart
static final WindTestConfig current = WindTestConfig.fastBackingLeft();
```

### Vent stable pour déboguer
```dart
static final WindTestConfig current = WindTestConfig.stable();
```

### Conditions de régate réalistes
```dart
static final WindTestConfig current = WindTestConfig.irregular();
```

### Vent fort personnalisé
```dart
static final WindTestConfig current = WindTestConfig.chaotic(
  baseSpeed: 25.0,  // Vent à 25 nœuds !
);
```

---

**Après modification** : Redémarrez Flutter (`Ctrl+C` puis `flutter run`)

**Architecture** : Un seul fichier, configuration claire, 8 presets + personnalisation infinie ! 🎯