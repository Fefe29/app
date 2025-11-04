# Affichage des flèches vectorielles dans les GRIBs

## 🎯 Améliorations apportées

Vous avez demandé d'afficher **les flèches** EN PLUS de la heatmap. C'est maintenant fait !

## 📊 Visualisation combinée

### Avant ❌
- Seulement une heatmap (fond coloré gradient)
- Pas d'indication de direction

### Après ✅
- 🌈 **Heatmap** (fond coloré) = Intensité/magnitude
- ⬆️ **Flèches vectorielles** = Direction ET magnitude
- Les deux sont superposées pour une meilleure compréhension

## 🔧 Modifications effectuées

### 1. **grib_file_loader.dart**
- ✅ `loadGridFromGribFile()` : Charge la grille scalaire (pression, température, etc.)
- ✅ **NOUVEAU** `loadWindVectorsFromGribFile()` : Génère les composantes U et V du vent
  - U = Composante Est (positive = vent vers l'Est)
  - V = Composante Nord (positive = vent vers le Nord)
  - Simule un champ rotatif réaliste pour test

### 2. **grib_overlay_providers.dart**
- ✅ `currentGribGridProvider` : La grille scalaire (heatmap)
- ✅ **NOUVEAU** `currentGribUGridProvider` : Composante U du vent
- ✅ **NOUVEAU** `currentGribVGridProvider` : Composante V du vent

### 3. **course_canvas.dart**
- ✅ Affichage de la heatmap (GribGridPainter)
- ✅ **NOUVEAU** Affichage des flèches (GribVectorFieldPainter) par-dessus

### 4. **grib_layers_panel.dart**
- ✅ Au clic sur une variable:
  1. Charge les données scalaires
  2. **NOUVEAU** Charge automatiquement les vecteurs U/V
  3. Affiche heatmap + flèches

## 📍 Comment ça marche ?

```
Utilisateur clique sur "wind10m"
         ↓
Chargement du fichier GRIB
         ↓
┌─────────────────────────────────┐
│ loadGridFromGribFile()          │
│ → Génère magnitude du vent      │
│ → Crée heatmap colorée          │
└─────────────────────────────────┘
         ↓
┌─────────────────────────────────┐
│ loadWindVectorsFromGribFile()   │
│ → Génère composantes U et V     │
│ → Crée vecteurs du vent         │
└─────────────────────────────────┘
         ↓
┌─────────────────────────────────┐
│ Affichage sur la carte:         │
│ 1. GribGridPainter (heatmap)    │
│ 2. GribVectorFieldPainter (→)   │
└─────────────────────────────────┘
```

## 🎨 Interprétation visuelle

### Heatmap (fond coloré)
- **Bleu** = Vent/courant faible (5 m/s)
- **Vert** = Vent/courant modéré (10 m/s)
- **Rouge** = Vent/courant fort (20+ m/s)

### Flèches (→)
- **Longueur** = Magnitude du vecteur
- **Direction** = Où va le vent/courant
- **Espacement** = Tous les 3 points du maillage (pour clarté)
- **Couleur** = Aussi basée sur la magnitude (bleu→rouge)

## 📐 Paramètres ajustables

### Dans `course_canvas.dart`:

```dart
GribVectorFieldPainter(
  uGrid: gribUGrid,
  vGrid: gribVGrid,
  vmin: 0.0,
  vmax: 20.0,              // ← Vitesse max (m/s)
  opacity: gribOpacity * 0.9,
  samplingStride: 3,       // ← Tous les 3 points (1=chaque point, 4=moins dense)
)
```

Pour **plus de flèches** : Diminuez `samplingStride` (ex: 2 au lieu de 3)
Pour **moins de flèches** : Augmentez `samplingStride` (ex: 5 ou 6)

## 🧪 Test rapide

1. Lancez l'app
2. Allez sur Charts
3. Ouvrez "Couches météo" (☁️ icône)
4. Cliquez sur `wind10m`
5. Vous devriez voir:
   - 🌈 Un dégradé de couleurs (heatmap)
   - ⬆️ Des flèches superposées (vecteurs)

Les flèches s'organisent en pattern rotatif (anticyclone simulé).

## ⚠️ Note importante

Les données affichées sont **SIMULÉES** pour test. Les vecteurs sont générés par une formule mathématique:

```dart
// Champ rotatif réaliste (anticyclone)
final angle = math.atan2(lat, lon);
final r = math.sqrt(lon * lon + lat * lat) / 100;
final speed = (math.sin(r) + 1.5) * 5;    // 0..15 m/s
final windDir = angle + 0.5;
uValues[...] = math.sin(windDir) * speed;
vValues[...] = math.cos(windDir) * speed;
```

## 🔜 Prochaines étapes

1. **Parsing GRIB réel** : Remlacer la simulation par de vrais fichiers GRIB
2. **Seuil de magnitude** : Masquer les vecteurs très faibles (< 1 m/s)
3. **Flèches adaptatives** : Taille variable selon magnitude
4. **Sélecteur temps** : Naviguer entre f000/f003/f006/etc.

---

**État**: ✅ Heatmap + Flèches fonctionnelles et superposées
