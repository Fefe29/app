# Fixes pour la visibilité des GRIB

## Problèmes corrigés

### 1. ❌ Les fichiers GRIB n'étaient pas trouvés dans la fenêtre "Gérer les fichiers gribs"
**Cause** : `grib_layers_panel.dart` utilisait un chemin hardcodé erroné
```dart
// AVANT (INCORRECT)
final repoDir = Directory(
  '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/gribs/repositories',
);
```

**Solution** : Utiliser `getGribDataDirectory()` de manière asynchrone
```dart
// APRÈS (CORRECT)
final repoDir = await getGribDataDirectory();
```

**Fichier modifié** : `lib/features/charts/presentation/widgets/grib_layers_panel.dart`
- Ajout import : `import '../../../../common/kornog_data_directory.dart';`
- Modification : `_showGribManagerDialog()` maintenant utilise `await getGribDataDirectory()`

### 2. ❌ Le fond vert (GRIB) ne disparaît pas quand on décoche "Afficher les GRIBs"
**Cause** : `course_canvas.dart` n'utilisait pas le `gribVisibilityProvider` pour afficher/masquer les couches

**Solution** : Ajouter la vérification `&& gribVisible` dans les conditions `if`
```dart
// AVANT
if (gribGrid != null)
  IgnorePointer(child: ...)

// APRÈS  
if (gribGrid != null && gribVisible)
  IgnorePointer(child: ...)
```

**Fichier modifié** : `lib/features/charts/presentation/widgets/course_canvas.dart`
- Ajout watch : `final gribVisible = ref.watch(gribVisibilityProvider);`
- Ajout import : `import '../../providers/grib_layers_provider.dart';`
- Modification ligne ~282 : `if (gribGrid != null && gribVisible)`
- Modification ligne ~303 : `if (gribUGrid != null && gribVGrid != null && gribVisible)`

## Résultat

✅ Les fichiers GRIB sont maintenant trouvés dans la fenêtre de gestion
✅ L'affichage des GRIB peut être désactivé en décochant "Afficher les GRIBs"
✅ Les vecteurs (flèches) suivent la même visibilité

## Test

1. Lancez l'app : `flutter run -d linux`
2. Allez à "Gérer les fichiers gribs"
3. Vérifiez que les fichiers GRIB sont listés ✅
4. Allez à la carte et cochez "Afficher les GRIBs" pour voir le fond vert ✅
5. Décochez "Afficher les GRIBs" - le fond vert disparaît ✅
6. Les flèches disparaissent aussi ✅
