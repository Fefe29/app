# Guide d'utilisation des GRIBs dans Kornog

## Vue d'ensemble

Les données GRIB (Gridded Binary) permettent de visualiser des données météorologiques (vent, pression, etc.) sur la carte. Le système a été restructuré pour afficher correctement ces données sur la carte.

## Composants mis en place

### 1. **Modèles GRIB** (`grib_models.dart`)
- **ScalarGrid**: Représente une grille régulière de valeurs (ex: vitesse du vent)
- **ColorMap**: Palette de couleurs pour afficher les données (blueToRed, greenYellowRed, parula)

### 2. **Painters GRIB** (`grib_painters.dart`)
- **GribGridPainter**: Affiche une grille scalaire en tant que heatmap
- **GribVectorFieldPainter**: Affiche les vecteurs (vent, courants) avec des flèches

### 3. **Providers GRIB** (`grib_overlay_providers.dart`)
- `currentGribGridProvider`: La grille actuellement affichée
- `gribOpacityProvider`: Contrôle la transparence (0..1)
- `gribVminProvider` / `gribVmaxProvider`: Bornes de la palette de couleurs
- `gribVariablesProvider`: Ensemble des variables GRIB sélectionnées

### 4. **Chargeur de fichiers** (`grib_file_loader.dart`)
- Cherche les fichiers GRIB stockés localement
- Charge et simule le parsing des données (voir TODO pour vrai parsing)

### 5. **Intégration dans CourseCanvas** (`course_canvas.dart`)
- Une couche GRIB a été ajoutée au Stack de rendu
- Elle s'affiche entre la carte de base et les éléments de navigation
- L'opacité peut être contrôlée via un provider

### 6. **Panneau de contrôle** (`grib_layers_panel.dart`)
- Affiche les variables GRIB disponibles
- Au clic sur une variable, elle est automatiquement chargée et affichée

## Comment utiliser

### Étape 1: Télécharger des données GRIB

1. Ouvrez Kornog sur la page chart
2. Cliquez sur le bouton "Couches météo" (icône nuage) dans la barre d'outils
3. Sélectionnez un modèle météo (ex: GFS 0.25°)
4. Sélectionnez les variables désirées (ex: vent10m, pression)
5. Configurez la zone et la période
6. Cliquez sur "Télécharger la sélection"

Les fichiers GRIB seront stockés dans:
```
lib/data/datasources/gribs/repositories/GFS_0p25/20251025T12/
```

### Étape 2: Afficher les GRIBs sur la carte

1. Allez dans le panneau "Couches météo"
2. Sélectionnez l'une des variables GRIB disponibles (ex: wind10m)
3. Un heatmap devrait apparaître sur la carte

### Étape 3: Contrôler l'affichage

- **Activation/Désactivation**: Le switch "Afficher les GRIBs" contrôle la visibilité
- **Opacité**: Utilisez le slider d'opacité (TODO: à ajouter dans le panneau)
- **Palette de couleurs**: Les données sont affichées en gradient bleu→rouge

## Améliorations nécessaires

### 1. Parsing GRIB réel
Actuellement, `grib_file_loader.dart` retourne une grille de test (sinusoïde). 
Pour le parsing réel des fichiers GRIB2, intégrez:
- **eccodes** (C library) ou
- **cfgrib** (Python) via FFI ou
- **pygrib** wrapper Dart

### 2. Support des vecteurs
Le vent est composé de (U, V). Il faudrait:
- Charger U et V séparément
- Utiliser `GribVectorFieldPainter` au lieu de `GribGridPainter`
- Afficher les vecteurs sous forme de flèches

### 3. Sélecteur de temps
Les fichiers GRIB contiennent plusieurs pas de temps (f000, f003, f006, etc.).
À implémenter:
- Slider pour naviguer dans le temps
- Mise à jour de la grille affichée

### 4. Palette de couleurs variable
Actuellement seul blueToRed est utilisé. À ajouter:
- Dropdown pour choisir la palette
- Support de plus de palettes météo standard

## Dépannage

### Les GRIBs n'apparaissent pas?
1. Vérifiez que des fichiers sont présents dans `lib/data/datasources/gribs/repositories/`
2. Assurez-vous que le switch "Afficher les GRIBs" est activé
3. Regardez la console pour les messages d'erreur `[GRIB]`

### Les données semblent bizarres?
Le loader retourne actuellement une sinusoïde de test. Remplacez le parsing pour utiliser les vraies données GRIB.

## Fichiers créés/modifiés

| Fichier | Statut | Description |
|---------|--------|-------------|
| `grib_models.dart` | ✅ Créé | Modèles de données GRIB |
| `grib_painters.dart` | ✅ Créé | Painters pour afficher les gribs |
| `grib_overlay_providers.dart` | ✅ Créé | Providers Riverpod |
| `grib_file_loader.dart` | ✅ Créé | Chargeur de fichiers |
| `course_canvas.dart` | ✅ Modifié | Ajout de la couche GRIB au Stack |
| `grib_layers_panel.dart` | ✅ Modifié | Intégration du chargement automatique |

---

**Note**: Ce guide suppose Flutter 3.x+ et Riverpod 2.x+
