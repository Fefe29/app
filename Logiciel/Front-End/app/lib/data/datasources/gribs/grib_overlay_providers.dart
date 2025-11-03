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
    // Au démarrage, charger automatiquement un GRIB si disponible
    final files = await GribFileLoader.findGribFiles();
    
    if (files.isNotEmpty) {
      // Charger le premier fichier
      final grid = await GribFileLoader.loadGridFromGribFile(files.first);
      
      if (grid != null) {
        // Mettre à jour le provider de grille courante
        ref.read(currentGribGridProvider.notifier).setGrid(grid);
        
        // Calculer et définir les bornes
        final (vmin, vmax) = grid.getValueBounds();
        ref.read(gribVminProvider.notifier).setVmin(vmin);
        ref.read(gribVmaxProvider.notifier).setVmax(vmax);
      }
    }
  }
}

final autoLoadGribGridProvider = AsyncNotifierProvider<AutoLoadGribGridNotifier, void>(
  AutoLoadGribGridNotifier.new,
);
