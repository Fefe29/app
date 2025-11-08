import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'grib_models.dart';
import 'grib_file_loader.dart';
import 'grib_downloader.dart';

// ============================================================
// PROVIDERS POUR GÉRER LES DONNÉES GRIB AFFICHÉES SUR LA CARTE
// ============================================================

/// Notifier pour la grille courante à afficher
class CurrentGribGridNotifier extends Notifier<ScalarGrid?> {
  @override
  ScalarGrid? build() => null;

  void setGrid(ScalarGrid? grid) => state = grid;
  void clear() => state = null;
}

final currentGribGridProvider = NotifierProvider<CurrentGribGridNotifier, ScalarGrid?>(
  CurrentGribGridNotifier.new,
);

/// Notifier pour la grille U (composante Est du vent)
class CurrentGribUGridNotifier extends Notifier<ScalarGrid?> {
  @override
  ScalarGrid? build() => null;

  void setGrid(ScalarGrid? grid) => state = grid;
  void clear() => state = null;
}

final currentGribUGridProvider = NotifierProvider<CurrentGribUGridNotifier, ScalarGrid?>(
  CurrentGribUGridNotifier.new,
);

/// Notifier pour la grille V (composante Nord du vent)
class CurrentGribVGridNotifier extends Notifier<ScalarGrid?> {
  @override
  ScalarGrid? build() => null;

  void setGrid(ScalarGrid? grid) => state = grid;
  void clear() => state = null;
}

final currentGribVGridProvider = NotifierProvider<CurrentGribVGridNotifier, ScalarGrid?>(
  CurrentGribVGridNotifier.new,
);

/// Provider pour stocker le dernier fichier GRIB chargé
class LastLoadedGribFileNotifier extends Notifier<File?> {
  @override
  File? build() => null;

  void setFile(File? file) => state = file;
  void clear() => state = null;
}

final lastLoadedGribFileProvider = NotifierProvider<LastLoadedGribFileNotifier, File?>(
  LastLoadedGribFileNotifier.new,
);

/// Provider pour stocker le dossier GRIB actuellement actif (ex: GFS_0p25/20251103T12)
class ActiveGribDirectoryNotifier extends Notifier<Directory?> {
  @override
  Directory? build() => null;

  void setDirectory(Directory? dir) => state = dir;
  void clear() => state = null;
}

final activeGribDirectoryProvider = NotifierProvider<ActiveGribDirectoryNotifier, Directory?>(
  ActiveGribDirectoryNotifier.new,
);

// SUPPRIMÉ: ManualGribFileSelectionProvider
// Raison: Flags ne persistent pas correctement entre watcher re-triggers
// Nouvelle approche: Pas de watchers continus, seulement des appels directs à loadGribFile()

/// Notifier pour l'opacité des gribs (0..1)
class GribOpacityNotifier extends Notifier<double> {
  @override
  double build() => 0.6;

  void setOpacity(double v) => state = v.clamp(0.0, 1.0);
}

final gribOpacityProvider = NotifierProvider<GribOpacityNotifier, double>(
  GribOpacityNotifier.new,
);

/// Notifier pour la valeur minimale de la palette de couleurs
class GribVminNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  void setVmin(double v) => state = v;
}

final gribVminProvider = NotifierProvider<GribVminNotifier, double>(
  GribVminNotifier.new,
);

/// Notifier pour la valeur maximale de la palette de couleurs
class GribVmaxNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void setVmax(double v) => state = v;
}

final gribVmaxProvider = NotifierProvider<GribVmaxNotifier, double>(
  GribVmaxNotifier.new,
);

/// Notifier pour le nombre de vecteurs à afficher (mode interpolation)
/// Notifier pour les variables GRIB à afficher
class GribVariablesNotifier extends Notifier<Set<GribVariable>> {
  @override
  Set<GribVariable> build() => {};

  void toggle(GribVariable variable) {
    state = {...state};
    if (state.contains(variable)) {
      state.remove(variable);
    } else {
      state.add(variable);
    }
    state = {...state};
  }

  void setVariables(Set<GribVariable> vars) => state = {...vars};
}

final gribVariablesProvider = NotifierProvider<GribVariablesNotifier, Set<GribVariable>>(
  GribVariablesNotifier.new,
);

/// Provider pour charger automatiquement un GRIB au démarrage
class AutoLoadGribGridNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    print('[AUTO_LOAD] Starting GRIB auto-load...');
    
    // Au démarrage, charger automatiquement un GRIB si disponible
    final files = await GribFileLoader.findGribFiles();
    print('[AUTO_LOAD] Found ${files.length} GRIB files');
    
    if (files.isNotEmpty) {
      // Charger le premier fichier
      await loadGribFile(files.first, ref);
    } else {
      print('[AUTO_LOAD] No GRIB files found - NO FALLBACK to test data');
    }
  }
}

final autoLoadGribGridProvider = AsyncNotifierProvider<AutoLoadGribGridNotifier, void>(
  AutoLoadGribGridNotifier.new,
);

// SUPPRIMÉ: autoLoadGribFromActiveDirectoryProvider
// Raison: Watchers continus causaient des re-déclenchements infinies
// Nouvelle approche: 
// - Auto-load une SEULE FOIS au démarrage (autoLoadGribGridProvider)
// - Sélections manuelles via appels directs à loadGribFile() (pas de watcher)
// - Pas de "magic" - l'utilisateur garde le dernier fichier qu'il a choisi jusqu'à redémarrage

/// Notifier pour l'heure de prévision GRIB actuelle (en heures)
/// Par défaut: 0 = analyse (ou .anl ou .f000)
/// Valeurs possibles: 0, 3, 6, 9, 12, 15, 18, 21, 24, ... 72
class GribForecastHourNotifier extends Notifier<int> {
  @override
  int build() => 0; // Démarrer à l'analyse

  void setForecastHour(int hour) => state = hour;
  void incrementHour(int delta) => state = (state + delta).clamp(0, 72);
}

final gribForecastHourProvider = NotifierProvider<GribForecastHourNotifier, int>(
  GribForecastHourNotifier.new,
);

/// Fonction helper pour charger un fichier GRIB et mettre à jour tous les providers
/// Cette fonction est appelée depuis AutoLoadGribGridNotifier et les watchers
/// [isManualSelection] = true si l'utilisateur a sélectionné manuellement le fichier
/// [ref] peut être soit un Ref (async) soit un WidgetRef (widget)
Future<void> loadGribFile(
  File file,
  dynamic ref,
) async {
  print('[GRIB_LOAD] 📥 === CHARGEMENT D\'UN GRIB ===');
  print('[GRIB_LOAD] Fichier: ${file.path}');
  print('[GRIB_LOAD] Existe: ${file.existsSync()}');
  print('[GRIB_LOAD] Taille: ${file.lengthSync()} bytes');

  print('[GRIB_LOAD] 📖 Appel GribFileLoader.loadGridFromGribFile()...');

  // Charger la grille
  final grid = await GribFileLoader.loadGridFromGribFile(file);
  print('[GRIB_LOAD] Grid result: $grid');
  
  if (grid != null) {
    final (vmin, vmax) = grid.getValueBounds();
    print('[GRIB_LOAD] ✅ Grid chargée: ${grid.nx}x${grid.ny}, values: $vmin..$vmax');
    
    ref.read(currentGribGridProvider.notifier).setGrid(grid);
    ref.read(gribVminProvider.notifier).setVmin(vmin);
    ref.read(gribVmaxProvider.notifier).setVmax(vmax);
    
    // Stocker le dernier fichier chargé
    // Cela permet de reprendre le dernier fichier chargé si l'app redémarre
    print('[GRIB_LOAD] � Stockage du fichier dans lastLoadedGribFileProvider');
    ref.read(lastLoadedGribFileProvider.notifier).setFile(file);

    // Mettre à jour le dossier GRIB actif (parent du fichier)
    final parts = file.path.split('/');
    if (parts.length >= 2) {
      // Construire le chemin du dossier parent (model/cycle)
      final dirPath = parts.sublist(0, parts.length - 1).join('/');
      final directory = Directory(dirPath);
      print('[GRIB_LOAD] 📁 Mise à jour du dossier actif: ${directory.path}');
      ref.read(activeGribDirectoryProvider.notifier).setDirectory(directory);
    }

    // Charger aussi les vecteurs U/V automatiquement
    print('[GRIB_LOAD] 🧭 Appel GribFileLoader.loadWindVectorsFromGribFile()...');
    final (uGrid, vGrid) = await GribFileLoader.loadWindVectorsFromGribFile(file);
    print('[GRIB_LOAD] Vecteurs: U=$uGrid, V=$vGrid');
    
    if (uGrid != null && vGrid != null) {
      ref.read(currentGribUGridProvider.notifier).setGrid(uGrid);
      ref.read(currentGribVGridProvider.notifier).setGrid(vGrid);
      print('[GRIB_LOAD] ✅ Vecteurs U/V chargés et stockés');
    } else {
      print('[GRIB_LOAD] ⚠️ Vecteurs U/V null: U=$uGrid, V=$vGrid');
    }
  } else {
    print('[GRIB_LOAD] ❌ Impossible de charger la grid');
  }
}

