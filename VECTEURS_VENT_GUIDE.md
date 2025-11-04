# 🧭 Guide - Maillage des Vecteurs de Vent

## Qu'avons-nous implémenté ?

Un système pour **afficher les vecteurs de vent (U/V)** depuis les données GRIB avec deux modes :

### 📌 Mode 1: **Legacy (Stride)**
- **Défaut**: Utilise `samplingStride = 3` (affiche 1 flèche tous les 3 points GRIB)
- **Avantage**: Rapide, peu de calcul
- **Inconvénient**: Nombre de vecteurs dépend de la résolution GRIB (145x73 → ~24x8 = 192 max)

### 📌 Mode 2: **Interpolé (Adaptive)**
- **Nouveau**: Affiche exactement N vecteurs uniformément espacés
- **Avantage**: Contrôle précis du maillage (2-20 vecteurs)
- **Fonctionnement**: Génère une grille régulière NxN et interpole U/V avec bilinéaire

## 🎮 Comment utiliser

### Étape 1 : Charger un GRIB
1. Ouvrez le panneau **"Couches GRIB"** (nuage en haut à gauche)
2. Cliquez sur l'icône 📁 **"Gérer les fichiers GRIB"**
3. Sélectionnez un modèle → une date → un fichier GRIB
4. Les vecteurs U/V se chargent **automatiquement**

### Étape 2 : Contrôler le maillage
Dans le panneau **"Couches GRIB"**, vous verrez :

```
Maillage des Vecteurs de Vent
Nombre de vecteurs à afficher (interpolation)

[━━━━━━━━━━━ 0 ━━━━━━━━━━━━━]    [Auto]

📍 Affichage standard (espacé selon résolution GRIB)
```

- **Slider à 0 (Auto)**: Mode Legacy (stride=3)
- **Slider à 1-20**: Mode Interpolé (N vecteurs)

### Étape 3 : Visualiser
- Les vecteurs sont **CYAN très épais** (6px) → faciles à voir sur la heatmap verte
- Tous les vecteurs sont **visibles simultanément** (pas d'animation)
- Basés sur la **première prévision chargée** (f000, f012, etc.)

## 🔧 Paramètres Techniques

### Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `grib_models.dart` | ✨ Ajout `generateInterpolatedGridPoints()` |
| `grib_painters.dart` | ✨ Mode interpolé dans `GribVectorFieldPainter` |
| `grib_overlay_providers.dart` | ✨ Nouveau `gribVectorCountProvider` |
| `grib_layers_panel.dart` | ✨ Slider de contrôle |
| `course_canvas.dart` | ✨ Passage du provider au painter |

### Configuration par défaut

```dart
// Mode legacy (stride)
samplingStride = 3              // 1 flèche tous les 3 points
targetVectorCount = null        // null = utilise stride

// Rendu
strokeWidth = 6.0               // Très épais, visible
color = Colors.cyan             // Opaque, visible sur vert

// Interpolation
pointsPerSide = sqrt(targetVectorCount)  // Grille carrée
```

## 🐛 Dépannage

### Les vecteurs ne s'affichent pas
1. Vérifiez que **"Afficher les GRIBs"** est activé ✅
2. Vérifiez que vous avez **chargé un GRIB** (vous devriez voir la heatmap verte)
3. Vérifiez les **logs console** :
   ```
   [GRIB_VECTORS_PAINTER] 🎯 PAINT APPELÉ
   [GRIB_VECTORS_PAINTER] ✅ RÉSULTAT: X dessinées
   ```

### Les flèches sont trop nombreuses / figent l'écran
- Baissez le slider (max 20 vecteurs)
- Utilisez "Auto" (mode Legacy) pour revenir à 192 max

### Les flèches ne sont pas au bon endroit
- Vérifiez la projection Mercator dans `course_canvas.dart`
- Les flèches doivent être superposées à la heatmap

## 📈 Amélioration future possibles

1. **Animation temporelle**: Charger multiple f000/f012/f024 et scroller dans le temps
2. **Coloration par magnitude**: Les flèches changent de couleur selon la vitesse du vent
3. **Lissage**: Appliquer un filtre gaussien sur l'interpolation
4. **Zoom adaptatif**: Augmenter le nombre de vecteurs quand on zoom
5. **Export**: Télécharger un fichier GeoJSON avec les vecteurs

## 📚 Références

- **Interpolation bilinéaire**: `ScalarGrid.sampleAtLatLon()`
- **Grille de points**: `ScalarGrid.generateInterpolatedGridPoints()`
- **Painter**: `GribVectorFieldPainter` (mode interpolé OU legacy)
- **Provider**: `gribVectorCountProvider` (null = stride, N = interpolé)

---

**Testé avec**: GFS 0.25°, données U10/V10 (vent à 10m)
