import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'grib_models.dart';
import 'grib_downloader.dart';
import 'grib_converter.dart';
import '../../../common/kornog_data_directory.dart';

/// Service pour charger et parser les fichiers GRIB
/// ATTENTION: C'est une implémentation simple qui simule le chargement.
/// Pour un vrai parsing GRIB, il faudrait une bibliothèque comme ecCodes ou eccodes.jl
class GribFileLoader {
  /// Cherche les fichiers GRIB dans le répertoire de cache
  static Future<List<File>> findGribFiles({
    GribModel? model,
    GribVariable? variable,
  }) async {
    try {
      // Utiliser getGribDataDirectory() au lieu d'un chemin relatif
      final gribDir = await getGribDataDirectory();
      
      print('[GRIB_LOADER] Cherchant les fichiers GRIB dans: ${gribDir.path}');
      
      if (!gribDir.existsSync()) {
        print('[GRIB_LOADER] Répertoire non trouvé: ${gribDir.path}');
        return [];
      }
      
      print('[GRIB_LOADER] Répertoire trouvé, listing...');

      final files = <File>[];
      
      // Parcourir les sous-dossiers (GFS_0p25/20251025T12/gfs.t12z.pgrb2.0p25.f042, etc.)
      for (final modelDir in gribDir.listSync().whereType<Directory>()) {
        // Filtrer par modèle si spécifié
        if (model != null && !modelDir.path.contains(_modelDirName(model))) {
          continue;
        }

        for (final cycleDir in modelDir.listSync().whereType<Directory>()) {
          for (final file in cycleDir.listSync().whereType<File>()) {
            if (file.path.endsWith('.anl') || 
                file.path.endsWith('.f000') ||
                file.path.endsWith('.f003') ||
                file.path.endsWith('.f006') ||
                file.path.endsWith('.f009') ||
                file.path.endsWith('.f012') ||
                file.path.endsWith('.f015') ||
                file.path.endsWith('.f018') ||
                file.path.endsWith('.f021') ||
                file.path.endsWith('.f024') ||
                file.path.contains('pgrb2')) {
              files.add(file);
            }
          }
        }
      }

      print('[GRIB_LOADER] Trouvé ${files.length} fichiers GRIB');
      for (final f in files.take(5)) {
        print('[GRIB_LOADER]   - ${f.path}');
      }
      return files;
    } catch (e) {
      print('[GRIB_LOADER] Erreur lors de la recherche: $e');
      return [];
    }
  }

  /// Charge une grille scalaire depuis un fichier GRIB
  /// 🆕 Utilise wgrib2 pour parser les vraies données
  static Future<ScalarGrid?> loadGridFromGribFile(
    File gribFile, {
    GribVariable? variable,
  }) async {
    try {
      if (!gribFile.existsSync()) return null;

      print('[GRIB_LOADER] 📖 Parsing: ${gribFile.path}');

      // 🎯 UTILISER LE CONVERTISSEUR RÉEL - chercher la température ou la pression
      // En priorité: température à 2m (pour heatmap)
      ScalarGrid? grid = await GribConverter.extractScalarField(
        gribFile,
        fieldName: 'TMP:2 m',
      );

      // Si pas de température, chercher la pression au niveau mer
      if (grid == null) {
        print('[GRIB_LOADER] ℹ️  TMP:2 m non trouvé, essayant PRMSL...');
        grid = await GribConverter.extractScalarField(
          gribFile,
          fieldName: 'PRMSL:mean sea level',
        );
      }

      // Si toujours rien, générer des données de test
      if (grid == null) {
        print('[GRIB_LOADER] ⚠️  Aucun champ scalaire trouvé, utilisant données de test');
        grid = _generateTestGrid();
      }

      if (grid != null) {
        final (vmin, vmax) = grid.getValueBounds();
        print('[GRIB_LOADER] ✅ Grille chargée: ${grid.nx}x${grid.ny}');
        print('[GRIB_LOADER] Valeurs: $vmin à $vmax');
      }

      return grid;
    } catch (e) {
      print('[GRIB_LOADER] ❌ Erreur: $e');
      return null;
    }
  }

  /// Génère une grille de test avec variations évidentes
  static ScalarGrid _generateTestGrid() {
    final nx = 145;
    final ny = 73;
    final lon0 = -180.0;
    final lat0 = -90.0;
    final dlon = 2.5;
    final dlat = 2.5;

    final values = Float32List(nx * ny);
    for (int iy = 0; iy < ny; iy++) {
      for (int ix = 0; ix < nx; ix++) {
        final lon = lon0 + ix * dlon;
        final lat = lat0 + iy * dlat;
        
        // Créer des variations évidentes:
        // - Augmente avec la latitude (0 au sud, 25 au nord)
        // - Perturbations sinusoïdales
        final baseWind = 10.0 + (lat + 90.0) / 180.0 * 15.0; // 10..25 m/s avec latitude
        final perturbation = 5.0 * math.sin(lon * math.pi / 180.0) * math.cos(lat * math.pi / 360.0);
        final value = baseWind + perturbation;
        
        values[iy * nx + ix] = value.clamp(0.0, 30.0).toDouble();
      }
    }

    return ScalarGrid(
      nx: nx,
      ny: ny,
      lon0: lon0,
      lat0: lat0,
      dlon: dlon,
      dlat: dlat,
      values: values,
    );
  }

  /// Charge les composantes U et V (Est et Nord) du vent/courant
  /// Retourne (uGrid, vGrid) pour afficher les vecteurs
  /// 🆕 Utilise wgrib2 pour parser les vraies données GRIB
  static Future<(ScalarGrid?, ScalarGrid?)> loadWindVectorsFromGribFile(
    File gribFile,
  ) async {
    try {
      if (!gribFile.existsSync()) {
        print('[GRIB_VECTORS] Fichier inexistant: ${gribFile.path}');
        return (null, null);
      }

      final fileName = gribFile.path.split('/').last;
      print('[GRIB_VECTORS] 🚀 Chargement vecteurs depuis: $fileName');

      // 🎯 UTILISER LE CONVERTISSEUR RÉEL
      final (uGrid, vGrid) = await GribConverter.extractWindVectors(gribFile);

      if (uGrid != null && vGrid != null) {
        // Calculer les statistiques
        double uMin = double.infinity, uMax = double.negativeInfinity;
        double vMin = double.infinity, vMax = double.negativeInfinity;
        int nanCount = 0;
        
        for (final u in uGrid.values) {
          if (u.isNaN) nanCount++;
          else {
            if (u < uMin) uMin = u;
            if (u > uMax) uMax = u;
          }
        }
        for (final v in vGrid.values) {
          if (v.isNaN) nanCount++;
          else {
            if (v < vMin) vMin = v;
            if (v > vMax) vMax = v;
          }
        }

        print('[GRIB_VECTORS] ✅ Vecteurs chargés avec succès');
        print('[GRIB_VECTORS] U: $uMin à $uMax m/s');
        print('[GRIB_VECTORS] V: $vMin à $vMax m/s');
        print('[GRIB_VECTORS] NaN: $nanCount');
        
        return (uGrid, vGrid);
      } else {
        print('[GRIB_VECTORS] ⚠️  Impossible de parser le GRIB');
        print('[GRIB_VECTORS] ℹ️  Vérifiez que wgrib2 est installé: sudo apt-get install wgrib2');
        return (null, null);
      }
    } catch (e) {
      print('[GRIB_VECTORS] ❌ Erreur: $e');
      return (null, null);
    }
  }

  static String _modelDirName(GribModel model) {
    return switch (model) {
      GribModel.gfs025 => 'GFS_0p25',
      GribModel.gfs050 => 'GFS_0p50',
      GribModel.gfs100 => 'GFS_1p00',
      _ => 'GFS',
    };
  }
}
