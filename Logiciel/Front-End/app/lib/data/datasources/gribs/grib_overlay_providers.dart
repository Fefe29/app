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
/// Si null, utilise samplingStride (mode legacy)
/// Si défini (ex: 20), affiche ~20 vecteurs interpolés uniformément
class GribVectorCountNotifier extends Notifier<int?> {
  @override
  int? build() => null; // null = mode stride, sinon nombre de vecteurs cible (DÉMARRE EN MODE LEGACY)

  void setCount(int? count) => state = count;
  void setInterpolated(int count) => state = count;
  void setLegacy() => state = null;
}

final gribVectorCountProvider = NotifierProvider<GribVectorCountNotifier, int?>(
  GribVectorCountNotifier.new,
);

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
      final grid = await GribFileLoader.loadGridFromGribFile(files.first);
      print('[AUTO_LOAD] Loaded grid from ${files.first.path}: ${grid != null ? "success" : "failed"}');
      
      if (grid != null) {
        print('[AUTO_LOAD] Grid: ${grid.nx}x${grid.ny}, values=[${grid.values.length}]');
        print('[AUTO_LOAD] Grid bounds: lon(${grid.lon0}..${grid.lon0 + grid.dlon * grid.nx}), lat(${grid.lat0}..${grid.lat0 + grid.dlat * grid.ny})');
        
        // Mettre à jour le provider de grille courante
        ref.read(currentGribGridProvider.notifier).setGrid(grid);
        
        // Calculer et définir les bornes
        final (vmin, vmax) = grid.getValueBounds();
        print('[AUTO_LOAD] Value bounds: $vmin to $vmax (range: ${(vmax-vmin).abs()})');
        ref.read(gribVminProvider.notifier).setVmin(vmin);
        ref.read(gribVmaxProvider.notifier).setVmax(vmax);
        
        // Charger aussi les grilles U et V (vecteur vent)
        try {
          final (uGrid, vGrid) = await GribFileLoader.loadWindVectorsFromGribFile(files.first);
          
          if (uGrid != null) {
            print('[AUTO_LOAD] U-grid loaded: ${uGrid.nx}x${uGrid.ny}');
            ref.read(currentGribUGridProvider.notifier).setGrid(uGrid);
          } else {
            print('[AUTO_LOAD] Failed to load U-grid');
          }
          
          if (vGrid != null) {
            print('[AUTO_LOAD] V-grid loaded: ${vGrid.nx}x${vGrid.ny}');
            ref.read(currentGribVGridProvider.notifier).setGrid(vGrid);
          } else {
            print('[AUTO_LOAD] Failed to load V-grid');
          }
        } catch (e) {
          print('[AUTO_LOAD] Error loading U/V grids: $e');
        }
      }
    } else {
      print('[AUTO_LOAD] No GRIB files found!');
    }
  }
}

final autoLoadGribGridProvider = AsyncNotifierProvider<AutoLoadGribGridNotifier, void>(
  AutoLoadGribGridNotifier.new,
);

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
