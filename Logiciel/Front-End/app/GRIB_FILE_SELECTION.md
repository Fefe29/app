# Sélection et affichage des fichiers GRIB

## Nouvelle fonctionnalité

La fenêtre "Gérer les fichiers gribs" permet maintenant de :
1. **Lister tous les fichiers GRIB** disponibles dans `~/.local/share/kornog/KornogData/grib/`
2. **Sélectionner un fichier** en cliquant dessus
3. **Charger le fichier** sur la carte
4. **Afficher/Masquer** les GRIBs avec le switch "Afficher les GRIBs"

## Fichier modifié

**`lib/features/charts/presentation/widgets/grib_layers_panel.dart`**

### Avant
```dart
// Affichait juste les dossiers (GFS_0p25, etc.)
// Permettait de les supprimer
```

### Après
```dart
Future<void> _showGribManagerDialog() async {
  final gribDir = await getGribDataDirectory();
  
  // Récupérer TOUS les fichiers GRIB
  final allFiles = <File>[];
  for (final modelDir in gribDir.listSync().whereType<Directory>()) {
    for (final cycleDir in modelDir.listSync().whereType<Directory>()) {
      for (final file in cycleDir.listSync().whereType<File>()) {
        if (file.path.endsWith('.anl') || file.path.contains('pgrb2') || ...) {
          allFiles.add(file);
        }
      }
    }
  }
  
  // Afficher dans une ListView avec onTap pour charger
  ListTile(
    title: Text(fileName),
    onTap: () async {
      // Charger le fichier GRIB
      final grid = await GribFileLoader.loadGridFromGribFile(file);
      ref.read(currentGribGridProvider.notifier).setGrid(grid);
      // ... aussi charger U/V vecteurs
    },
  )
}
```

## Processus complet

```
1. Utilisateur clique "Gérer les fichiers gribs"
   ↓
2. Fenêtre affiche liste des ~50 fichiers GRIB
   ↓
3. Utilisateur sélectionne un fichier (ex: gfs.t12z.pgrb2.0p25.f006)
   ↓
4. Fichier chargé via GribFileLoader.loadGridFromGribFile()
   ↓
5. Grid + U/V vecteurs stockés dans les providers Riverpod
   ↓
6. CourseCanvas regarde les providers et affiche les couches GRIB
   ↓
7. Utilisateur voit le fond vert (heatmap) + flèches (vecteurs) sur la carte
   ↓
8. Utilisateur peut cocher/décocher "Afficher les GRIBs" pour montrer/masquer
```

## Dépendances

Les fonctions utilisées existent déjà :
- ✅ `getGribDataDirectory()` - obtient le répertoire GRIB
- ✅ `GribFileLoader.loadGridFromGribFile()` - charge la grille scalaire
- ✅ `GribFileLoader.loadWindVectorsFromGribFile()` - charge U/V
- ✅ `currentGribGridProvider.notifier.setGrid()` - stocke la grille
- ✅ `currentGribUGridProvider.notifier.setGrid()` - stocke U
- ✅ `currentGribVGridProvider.notifier.setGrid()` - stocke V
- ✅ `gribVminProvider.notifier.setVmin()` - règle min palette
- ✅ `gribVmaxProvider.notifier.setVmax()` - règle max palette

## Test

1. Lancez l'app : `flutter run -d linux`
2. Cliquez sur "Gérer les fichiers gribs"
3. Vous voyez une liste de ~50 fichiers GRIB ✅
4. Cliquez sur un fichier
5. Acceptez le message "GRIB chargé: ..."
6. Allez à la carte et cochez "Afficher les GRIBs"
7. Vous voyez le fond vert (heatmap) + flèches ✅
8. Décochez "Afficher les GRIBs" - tout disparaît ✅

## Améliorations possibles (futures)

- Ajouter un bouton "Actualiser" pour recharger la liste
- Afficher la date/cycle du fichier (parse du nom)
- Filtrer par modèle (GFS_0p25, etc.)
- Afficher la taille du fichier
- Ajouter des vignettes de preview
