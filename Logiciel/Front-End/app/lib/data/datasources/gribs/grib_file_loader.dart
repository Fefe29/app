import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'grib_models.dart';
import 'grib_downloader.dart';
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

  /// Simule le chargement d'une grille scalaire depuis un fichier GRIB
  /// ATTENTION: C'est une SIMULATION. Pour un vrai parsing, il faudrait eccodes ou similaire.
  static Future<ScalarGrid?> loadGridFromGribFile(
    File gribFile, {
    GribVariable? variable,
  }) async {
    // TODO: Implémenter le vrai parsing GRIB avec eccodes
    // Pour l'instant, on retourne une grille de démo
    
    try {
      // Vérifier que le fichier existe
      if (!gribFile.existsSync()) return null;

      // Grille de démo pour tester
      final nx = 145;
      final ny = 73;
      final lon0 = -180.0;
      final lat0 = -90.0;
      final dlon = 2.5;
      final dlat = 2.5;

      // Générer des données de test (sinusoïde)
      final values = Float32List(nx * ny);
      for (int iy = 0; iy < ny; iy++) {
        for (int ix = 0; ix < nx; ix++) {
          final lon = lon0 + ix * dlon;
          final lat = lat0 + iy * dlat;
          final value = math.sin(math.pi * lon / 180.0) * math.cos(math.pi * lat / 180.0);
          values[iy * nx + ix] = (value * 10 + 15).toDouble(); // Vent: 5..25 m/s
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
    } catch (e) {
      print('[GRIB] Erreur lors du chargement: $e');
      return null;
    }
  }

  /// Charge les composantes U et V (Est et Nord) du vent/courant
  /// Retourne (uGrid, vGrid) pour afficher les vecteurs
  /// ATTENTION: Génération de test - pour un vrai parsing, il faudrait eccodes
  static Future<(ScalarGrid?, ScalarGrid?)> loadWindVectorsFromGribFile(
    File gribFile,
  ) async {
    try {
      if (!gribFile.existsSync()) {
        print('[GRIB_VECTORS] Fichier inexistant: ${gribFile.path}');
        return (null, null);
      }

      final nx = 145;
      final ny = 73;
      final lon0 = -180.0;
      final lat0 = -90.0;
      final dlon = 2.5;
      final dlat = 2.5;

      // Générer U et V (composantes du vent)
      final uValues = Float32List(nx * ny); // Composante Est (U)
      final vValues = Float32List(nx * ny); // Composante Nord (V)

      // Extraire la date du nom du fichier pour une variation réaliste
      final fileName = gribFile.path.split('/').last;
      print('[GRIB_VECTORS] Chargement vecteurs depuis: $fileName');

      for (int iy = 0; iy < ny; iy++) {
        for (int ix = 0; ix < nx; ix++) {
          final lon = lon0 + ix * dlon;
          final lat = lat0 + iy * dlat;

          // Créer un champ de vent plus réaliste basé sur la position
          // Les vents dominants viennent d'ouest et augmentent avec la latitude
          final westerlies = 5.0 + (lat.abs() / 90.0) * 15.0; // 5-20 m/s
          
          // Perturbation locale basée sur lon/lat
          final perturbation = math.sin(lon * 0.05) * math.cos(lat * 0.05) * 5.0;
          
          // Composantes U (Est) et V (Nord)
          // Les westerlies donnent un vent d'ouest → composante U négative
          uValues[iy * nx + ix] = (-westerlies + perturbation).toDouble();
          
          // V varie avec la longitude (pattern méridien)
          vValues[iy * nx + ix] = (math.sin(lon * 0.1) * 8.0).toDouble();
        }
      }

      final uGrid = ScalarGrid(
        nx: nx,
        ny: ny,
        lon0: lon0,
        lat0: lat0,
        dlon: dlon,
        dlat: dlat,
        values: uValues,
      );

      final vGrid = ScalarGrid(
        nx: nx,
        ny: ny,
        lon0: lon0,
        lat0: lat0,
        dlon: dlon,
        dlat: dlat,
        values: vValues,
      );

      // Calculer les statistiques pour debug
      double uMin = double.infinity, uMax = double.negativeInfinity;
      double vMin = double.infinity, vMax = double.negativeInfinity;
      int nanCount = 0;
      
      for (final u in uValues) {
        if (u.isNaN) nanCount++;
        else {
          if (u < uMin) uMin = u;
          if (u > uMax) uMax = u;
        }
      }
      for (final v in vValues) {
        if (v.isNaN) nanCount++;
        else {
          if (v < vMin) vMin = v;
          if (v > vMax) vMax = v;
        }
      }

      print('[GRIB_VECTORS] ✅ Vecteurs générés avec succès');
      print('[GRIB_VECTORS] U: $uMin à $uMax m/s (NaN: $nanCount)');
      print('[GRIB_VECTORS] V: $vMin à $vMax m/s');
      
      return (uGrid, vGrid);
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
