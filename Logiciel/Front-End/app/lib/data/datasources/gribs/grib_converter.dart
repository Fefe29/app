import 'dart:io';
import 'dart:typed_data';
import 'grib_models.dart';

/// Convertisseur GRIB utilisant eccodes via script Python
/// Le script Python (parse_grib.py) gère les détails du parsing GRIB
class GribConverter {
  /// Chemin du script Python de parsing
  static const String _pythonScriptName = 'parse_grib.py';
  
  /// Chemins Python pour trouver cfgrib/xarray
  static String _getPythonPaths() {
    final homeDir = Platform.environment['HOME'] ?? '/home/fefe';
    return '$homeDir/.local/lib/python3.12/site-packages:'
           '/var/data/python/lib/python3.13/site-packages:'
           '/app/lib/python3.13/site-packages';
  }

  /// Obtient le chemin absolu du script Python
  static String _getScriptPath() {
    // Le script est dans le même répertoire que ce fichier
    // Chemin attendu: lib/data/datasources/gribs/parse_grib.py
    final scriptPath = '/home/fefe/Informatique/Projets/Kornog/app/Logiciel/Front-End/app/lib/data/datasources/gribs/parse_grib.py';
    return scriptPath;
  }

  /// Crée un Map d'environment avec PYTHONPATH pour les subprocesses
  static Map<String, String> _getEnvWithPythonPath() {
    final env = Map<String, String>.from(Platform.environment);
    // Ajouter tous les chemins Python standards
    final pythonPaths = [
      '/var/data/python/lib/python3.13/site-packages',
      '/app/lib/python3.13/site-packages',
      '/usr/lib/python3.13/site-packages',
      '/usr/lib/python3.13',
    ];
    final newPythonPath = pythonPaths.join(':');
    
    if (env.containsKey('PYTHONPATH')) {
      env['PYTHONPATH'] = '${env['PYTHONPATH']}:$newPythonPath';
    } else {
      env['PYTHONPATH'] = newPythonPath;
    }
    return env;
  }

  /// Vérifie si Python est disponible
  static Future<bool> isPythonAvailable() async {
    try {
      final result = await Process.run('python3', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Vérifie si eccodes est disponible via pip
  static Future<bool> isEccodesAvailable() async {
    try {
      // Test avec cfgrib+xarray en gardant tout l'environnement
      print('[GRIB_CONVERTER] Testing cfgrib availability...');
      
      final env = Map<String, String>.from(Platform.environment);
      final pythonPaths = _getPythonPaths();
      if (env.containsKey('PYTHONPATH')) {
        env['PYTHONPATH'] = '${env['PYTHONPATH']}:$pythonPaths';
      } else {
        env['PYTHONPATH'] = pythonPaths;
      }
      
      // DEBUG: afficher le sys.path que Python voit
      final pathResult = await Process.run(
        '/usr/bin/python3',
        ['-c', 'import sys; print("\\n".join(sys.path))'],
        environment: env,
      );
      print('[GRIB_CONVERTER] Python sys.path:\n${pathResult.stdout}');
      
      final result = await Process.run(
        '/usr/bin/python3',
        ['-c', 'import cfgrib; import xarray; print("1")'],
        environment: env,
      );
      final success = result.exitCode == 0 && result.stdout.toString().contains('1');
      if (success) {
        print('[GRIB_CONVERTER] ✅ cfgrib+xarray disponible');
      } else {
        print('[GRIB_CONVERTER] ⚠️ cfgrib not available');
        print('[GRIB_CONVERTER] stderr: ${result.stderr}');
        print('[GRIB_CONVERTER] PYTHONPATH in env: ${env['PYTHONPATH']}');
      }
      return success;
    } catch (e) {
      print('[GRIB_CONVERTER] Exception testing: $e');
      return false;
    }
  }

  /// Extrait les composantes U et V d'un fichier GRIB
  /// Retourne (uGrid, vGrid) ou (null, null) en cas d'erreur
  static Future<(ScalarGrid?, ScalarGrid?)> extractWindVectors(
    File gribFile,
  ) async {
    try {
      if (!gribFile.existsSync()) {
        print('[GRIB_CONVERTER] ❌ Fichier inexistant: ${gribFile.path}');
        return (null, null);
      }

      print('[GRIB_CONVERTER] 📖 Parsing: ${gribFile.path}');

      // Étape 1 : Vérifier Python et eccodes
      final hasPython = await isPythonAvailable();
      if (!hasPython) {
        print('[GRIB_CONVERTER] ⚠️  Python3 non disponible');
        return (null, null);
      }

      final hasEccodes = await isEccodesAvailable();
      if (!hasEccodes) {
        print('[GRIB_CONVERTER] ⚠️  eccodes non disponible');
        print('[GRIB_CONVERTER] ℹ️  Installation: pip install eccodes cfgrib xarray numpy');
        return (null, null);
      }

      print('[GRIB_CONVERTER] ✅ Extraction des données U/V avec parse_grib.py...');

      // Préparer l'environnement: garder TOUT et ajouter PYTHONPATH
      final env = Map<String, String>.from(Platform.environment);
      final pythonPaths = _getPythonPaths();
      if (env.containsKey('PYTHONPATH')) {
        env['PYTHONPATH'] = '${env['PYTHONPATH']}:$pythonPaths';
      } else {
        env['PYTHONPATH'] = pythonPaths;
      }

      // Étape 2 : Appeler le script Python pour extraire U
      print('[GRIB_CONVERTER] 📍 Extraction U (UGRD)...');
      final uResult = await Process.run(
        '/usr/bin/python3',
        [_getScriptPath(), gribFile.path, 'U'],
        environment: env,
      );

      if (uResult.exitCode != 0) {
        print('[GRIB_CONVERTER] ❌ Erreur extraction U: ${uResult.stderr}');
        return (null, null);
      }

      // Étape 3 : Appeler le script Python pour extraire V
      print('[GRIB_CONVERTER] 📍 Extraction V (VGRD)...');
      final vResult = await Process.run(
        '/usr/bin/python3',
        [_getScriptPath(), gribFile.path, 'V'],
        environment: env,
      );

      if (vResult.exitCode != 0) {
        print('[GRIB_CONVERTER] ❌ Erreur extraction V: ${vResult.stderr}');
        return (null, null);
      }

      // Étape 4 : Parser les données CSV
      print('[GRIB_CONVERTER] 🔄 Parsing des données CSV...');

      final uGrid = _parseGribCsv(uResult.stdout as String, 'U');
      final vGrid = _parseGribCsv(vResult.stdout as String, 'V');

      if (uGrid == null || vGrid == null) {
        print('[GRIB_CONVERTER] ❌ Erreur parsing CSV');
        return (null, null);
      }

      print('[GRIB_CONVERTER] ✅ Parsing réussi: U=${uGrid.nx}x${uGrid.ny}, V=${vGrid.nx}x${vGrid.ny}');
      return (uGrid, vGrid);
    } catch (e) {
      print('[GRIB_CONVERTER] ❌ Exception: $e');
      return (null, null);
    }
  }

  /// Parser les données CSV produites par wgrib2
  /// Format: record,id,grid,sub_grid,lat,lon,value
  static ScalarGrid? _parseGribCsv(String csv, String component) {
    try {
      final lines = csv.split('\n').where((l) => l.isNotEmpty).toList();
      
      if (lines.isEmpty) {
        print('[GRIB_CONVERTER] ⚠️  CSV vide pour $component');
        return null;
      }

      print('[GRIB_CONVERTER] 📈 $component: ${lines.length} lignes');

      // Parser les lignes CSV
      final points = <(double lon, double lat, double value)>[];
      
      for (final line in lines) {
        try {
          final parts = line.split(',');
          if (parts.length < 7) continue;

          final lat = double.parse(parts[4].trim());
          final lon = double.parse(parts[5].trim());
          final value = double.parse(parts[6].trim());

          points.add((lon, lat, value));
        } catch (e) {
          // Skip ligne malformée
        }
      }

      if (points.isEmpty) {
        print('[GRIB_CONVERTER] ⚠️  Aucun point valide pour $component');
        return null;
      }

      // Créer une grille régulière à partir des points
      return _createGridFromPoints(points, component);
    } catch (e) {
      print('[GRIB_CONVERTER] ❌ Erreur parsing: $e');
      return null;
    }
  }

  /// Crée une ScalarGrid régulière à partir de points épars
  static ScalarGrid? _createGridFromPoints(
    List<(double lon, double lat, double value)> points,
    String component,
  ) {
    try {
      if (points.isEmpty) return null;

      // Trouver les limites
      double lonMin = double.infinity;
      double lonMax = double.negativeInfinity;
      double latMin = double.infinity;
      double latMax = double.negativeInfinity;

      for (final (lon, lat, _) in points) {
        lonMin = lonMin < lon ? lonMin : lon;
        lonMax = lonMax > lon ? lonMax : lon;
        latMin = latMin < lat ? latMin : lat;
        latMax = latMax > lat ? latMax : lat;
      }

      print('[GRIB_CONVERTER] 🧭 Limites: lon [$lonMin, $lonMax], lat [$latMin, $latMax]');

      // Estimer la résolution (supposer une grille régulière)
      // Chercher les écarts min/max non-nuls
      final lons = points.map((p) => p.$1).toSet().toList()..sort();
      final lats = points.map((p) => p.$2).toSet().toList()..sort();

      double dlon = 1.0;
      double dlat = 1.0;

      if (lons.length > 1) {
        dlon = (lonMax - lonMin) / (lons.length - 1);
      }
      if (lats.length > 1) {
        dlat = (latMax - latMin) / (lats.length - 1);
      }

      final nx = lons.length;
      final ny = lats.length;

      print('[GRIB_CONVERTER] � Grille: ${nx}x${ny}, résolution: $dlon°x$dlat°');

      // Créer le array de valeurs
      final values = Float32List(nx * ny);
      values.fillRange(0, nx * ny, double.nan);

      // Remplir les valeurs
      for (final (lon, lat, value) in points) {
        // Trouver l'index (i, j) le plus proche
        int i = ((lon - lonMin) / dlon).round();
        int j = ((lat - latMin) / dlat).round();

        if (i >= 0 && i < nx && j >= 0 && j < ny) {
          values[j * nx + i] = value;
        }
      }

      return ScalarGrid(
        nx: nx,
        ny: ny,
        lon0: lonMin,
        lat0: latMin,
        dlon: dlon,
        dlat: dlat,
        values: values,
      );
    } catch (e) {
      print('[GRIB_CONVERTER] ❌ Erreur création grille: $e');
      return null;
    }
  }

  /// Charge la grille scalaire (ex: pression, température) d'un GRIB
  static Future<ScalarGrid?> extractScalarField(
    File gribFile, {
    String fieldName = 'TMP:2 m', // Par défaut: température à 2m
  }) async {
    try {
      if (!gribFile.existsSync()) {
        print('[GRIB_CONVERTER] ❌ Fichier inexistant: ${gribFile.path}');
        return null;
      }

      print('[GRIB_CONVERTER] 📖 Extraction scalaire: $fieldName');

      // Vérifier cfgrib
      final hasEccodes = await isEccodesAvailable();
      if (!hasEccodes) {
        print('[GRIB_CONVERTER] ⚠️  cfgrib non disponible pour extraction scalaire');
        return null;
      }

      // Préparer l'environnement: garder TOUT et ajouter PYTHONPATH
      final env = Map<String, String>.from(Platform.environment);
      final pythonPaths = _getPythonPaths();
      if (env.containsKey('PYTHONPATH')) {
        env['PYTHONPATH'] = '${env['PYTHONPATH']}:$pythonPaths';
      } else {
        env['PYTHONPATH'] = pythonPaths;
      }

      // Appeler le script Python
      final result = await Process.run(
        '/usr/bin/python3',
        [_getScriptPath(), gribFile.path, 'SCALAR', fieldName],
        environment: env,
      );

      if (result.exitCode != 0) {
        print('[GRIB_CONVERTER] ℹ️  Champ "$fieldName" non trouvé');
        return null;
      }

      // Parser les données
      final grid = _parseGribCsv(result.stdout as String, 'SCALAR');

      if (grid == null) {
        print('[GRIB_CONVERTER] ❌ Erreur parsing CSV scalaire');
        return null;
      }

      print('[GRIB_CONVERTER] ✅ Champ scalaire extrait: ${grid.nx}x${grid.ny}');
      return grid;
    } catch (e) {
      print('[GRIB_CONVERTER] ❌ Exception extraction scalaire: $e');
      return null;
    }
  }
}
