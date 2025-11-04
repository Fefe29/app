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

      // Si toujours rien, ERREUR - ne pas utiliser de données de test
      if (grid == null) {
        print('[GRIB_LOADER] ❌ Aucun champ scalaire trouvé dans le GRIB');
        print('[GRIB_LOADER] ℹ️  Vérifiez que cfgrib est installé: pip install cfgrib xarray');
        return null;
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
        print('[GRIB_VECTORS] ❌ Échec du chargement des vecteurs depuis le GRIB');
        print('[GRIB_VECTORS] ℹ️  Vérifiez que cfgrib/xarray est installé: pip install cfgrib xarray');
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
