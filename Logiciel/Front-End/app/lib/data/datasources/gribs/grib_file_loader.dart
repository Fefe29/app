import 'dart:io';
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
      
      print('[GRIB_LOADER] ════════════════════════════════════════');
      print('[GRIB_LOADER] 🔍 CHERCHANT LES FICHIERS GRIB');
      print('[GRIB_LOADER] Chemin: ${gribDir.path}');
      print('[GRIB_LOADER] Existe: ${gribDir.existsSync()}');
      
      if (!gribDir.existsSync()) {
        print('[GRIB_LOADER] ❌ Répertoire non trouvé!');
        print('[GRIB_LOADER] ❌ ERREUR: ${gribDir.path} n\'existe pas');
        print('[GRIB_LOADER] ❌ Crée le dossier manuellement sur ta tablette:');
        print('[GRIB_LOADER] ❌   /data/data/com.kornog.app/files/KornogData/grib/');
        print('[GRIB_LOADER] ════════════════════════════════════════');
        return [];
      }
      
      print('[GRIB_LOADER] ✅ Répertoire trouvé, listing les fichiers...');

      final files = <File>[];
      
      // Parcourir les sous-dossiers (GFS_0p25/20251025T12/gfs.t12z.pgrb2.0p25.f042, etc.)
      for (final modelDir in gribDir.listSync().whereType<Directory>()) {
        print('[GRIB_LOADER] 📁 Modèle: ${modelDir.path.split('/').last}');
        // Filtrer par modèle si spécifié
        if (model != null && !modelDir.path.contains(_modelDirName(model))) {
          continue;
        }

        for (final cycleDir in modelDir.listSync().whereType<Directory>()) {
          print('[GRIB_LOADER]   📅 Cycle: ${cycleDir.path.split('/').last}');
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
              // ⚠️ FILTRER LES FICHIERS VIDES
              final size = file.lengthSync();
              if (size == 0) {
                print('[GRIB_LOADER]     ⚠️  ${file.path.split('/').last} est VIDE (${size} bytes) - IGNORÉ');
                continue;
              }
              print('[GRIB_LOADER]     ✅ ${file.path.split('/').last} (${size / 1024 / 1024} MB)');
              files.add(file);
            }
          }
        }
      }

      print('[GRIB_LOADER] ✅ Trouvé ${files.length} fichiers GRIB');
      if (files.isEmpty) {
        print('[GRIB_LOADER] ⚠️  ATTENTION: Aucun fichier trouvé!');
        print('[GRIB_LOADER] ⚠️  Place tes fichiers GRIB dans: ${gribDir.path}');
      }
      for (final f in files.take(5)) {
        print('[GRIB_LOADER]   - ${f.path}');
      }
      return files;
    } catch (e) {
      print('[GRIB_LOADER] ❌ ERREUR lors de la recherche: $e');
      print('[GRIB_LOADER] ❌ Stack trace: $e');
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

      // 🎯 PRIORITÉ VENT - afficher la vitesse du vent à 10m (UGRD/VGRD)
      // En priorité: composante Est du vent (UGRD:10 m)
      ScalarGrid? grid = await GribConverter.extractScalarField(
        gribFile,
        fieldName: 'UGRD:10 m',
      );

      // Si pas de vent Est, essayer Nord
      if (grid == null) {
        print('[GRIB_LOADER] ℹ️  UGRD:10 m non trouvé, essayant VGRD:10 m...');
        grid = await GribConverter.extractScalarField(
          gribFile,
          fieldName: 'VGRD:10 m',
        );
      }

      // Si pas de vent 10m, chercher la température à 2m
      if (grid == null) {
        print('[GRIB_LOADER] ℹ️  VGRD:10 m non trouvé, essayant TMP:2 m...');
        grid = await GribConverter.extractScalarField(
          gribFile,
          fieldName: 'TMP:2 m',
        );
      }

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

  /// Liste tous les dossiers GRIB disponibles (model/cycle)
  /// Retourne une liste de répertoires triés par date (plus récent en premier)
  static Future<List<Directory>> findGribDirectories() async {
    try {
      final gribDir = await getGribDataDirectory();
      
      if (!gribDir.existsSync()) {
        return [];
      }

      final directories = <Directory>[];
      
      // Parcourir les sous-dossiers (GFS_0p25/20251025T12, etc.)
      for (final modelDir in gribDir.listSync().whereType<Directory>()) {
        for (final cycleDir in modelDir.listSync().whereType<Directory>()) {
          directories.add(cycleDir);
        }
      }
      
      // Trier par date (plus récent en premier)
      directories.sort((a, b) {
        final aName = a.path.split('/').last;
        final bName = b.path.split('/').last;
        return bName.compareTo(aName);
      });
      
      return directories;
    } catch (e) {
      print('[GRIB_LOADER] ❌ Erreur lors de la recherche des dossiers: $e');
      return [];
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
