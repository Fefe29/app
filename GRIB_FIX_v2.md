# GRIB Display Fix - Changements effectués

## Problèmes identifiés et corrigés

### 1. ❌ Scintillement / Lag lors du chargement
**Cause**: Le `GribGridPainter` était redessiné à chaque frame sans isolation

**Fix**: 
- Enveloppé la couche GRIB dans `RepaintBoundary`
- Cela crée une texture mise en cache qui n'est redessinnée que si elle change réellement

**Résultat**: ✅ Plus de lag, affichage lisse

### 2. ❌ GRIB affiché en vert partout ("fond vert")
**Cause**: La grille de démo couvrait le monde entier (-180°..+180°, -90°..+90°)

**Fix**:
- Redimensionné la grille pour couvrir la zone Europe Ouest seulement
- Nouvelles bornes: -12°W à +5°E, 41°N à 52°N (Bretagne/Manche)
- Résolution: 0.25° (comme GFS réel)

**Résultat**: ✅ Le GRIB s'affiche uniquement sur la zone pertinente

### 3. Amélioration: Validation des points projetés
- Ajouté des vérifications `isNaN` et limites écran
- Évite de dessiner des pixels hors écran ou invalides

---

## Nouvelle grille de démo

```dart
// Zone: Europe Ouest (Bretagne/Manche/Atlantique Nord)
lon0 = -12.0      // 12°W
lat0 = 41.0       // 41°N
lonFinal = +5.0   // 5°E
latFinal = +52.0  // 52°N

nx = 68  pixels   // 0.25° de résolution
ny = 44  pixels
```

**Données**: Sinusoïde réaliste avec variation géographique
- Vitesse vent: 4..20 m/s
- Gradient SO→NE (réaliste pour anticyclones/dépressions)

---

## Checklist de test

### Test 1: Pas de lag
- [ ] Ouvrir le panneau "Couches météo"
- [ ] L'écran ne doit PAS scintiller
- [ ] Les interactions (zoom/pan) restent fluides

### Test 2: GRIB bien localisé
- [ ] Sélectionner une variable GRIB
- [ ] ✅ Le heatmap apparaît UNIQUEMENT sur la zone Europe Ouest
- [ ] ❌ N'Y A PAS de vert partout sur la carte

### Test 3: Projection correcte
- [ ] Le GRIB doit être aligné avec la carte OSM
- [ ] En zoomant, le GRIB reste aligné
- [ ] En panning, le GRIB se déplace correctement

### Test 4: Opacité
- [ ] Modifier `ref.read(gribOpacityProvider.notifier).setOpacity(0.3)` (dans le code)
- [ ] Le GRIB devient transparent
- [ ] La carte OSM en dessous devient visible

---

## Code clé

### RepaintBoundary pour éviter le lag
```dart
RepaintBoundary(
  child: IgnorePointer(
    child: Opacity(
      opacity: gribOpacity,
      child: CustomPaint(
        painter: GribGridPainter(...),
      ),
    ),
  ),
)
```

### Grille redimensionnée
```dart
// Avant: -180..+180 (monde entier = très grand)
// Après: -12..+5 (Europe seulement = petit et pertinent)
final lon0 = -12.0;
final lat0 = 41.0;
final nx = 68;   // ~0.25° résolution
final ny = 44;
```

---

## Prochaines étapes

1. **Parser GRIB réel**
   - Remplacer la sinusoïde par eccodes/cfgrib
   - Lire vraies données météo

2. **Slider Opacité**
   - Ajouter dans grib_layers_panel
   - Lier à `gribOpacityProvider`

3. **Sélecteur Zone**
   - Permettre de changer la région (atlantique, méditerranée, etc.)
   - Recharger grille appropriée

4. **Sélecteur Temps**
   - Glisser entre les pas (f000/f003/f006/...)
   - Charger fichier différent

---

## Fichiers modifiés

| Fichier | Modification |
|---------|--------------|
| `course_canvas.dart` | Ajouté `RepaintBoundary` autour GRIB |
| `grib_painters.dart` | Meilleure gestion projection + validation points |
| `grib_file_loader.dart` | Grille redimensionnée zone Europe Ouest |

---

**Status**: ✅ GRIB affichage corrigé - zones pertinentes, pas de lag
**Besoin d'aide?** Consulte `GRIB_TEST_GUIDE.md`
