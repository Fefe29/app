import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Fournit le dossier de stockage principal pour les cartes Kornog, organisé et robuste,
/// compatible Android, iOS, Linux, Windows, macOS.
Future<Directory> getKornogDataDirectory() async {
  print('[KORNOG_DATA] ════════════════════════════════════════');
  print('[KORNOG_DATA] 📂 ENTERING getKornogDataDirectory');
  print('[KORNOG_DATA] Platform: ${Platform.operatingSystem}');
  
  Directory baseDir;
  if (Platform.isAndroid) {
    print('[KORNOG_DATA] 🔍 Platform is Android, getting app documents');
    baseDir = await getApplicationDocumentsDirectory();
    print('[KORNOG_DATA] ✅ Base dir: ${baseDir.path}');
  } else if (Platform.isIOS) {
    print('[KORNOG_DATA] 🔍 Platform is iOS');
    baseDir = await getApplicationDocumentsDirectory();
  } else if (Platform.isLinux) {
    print('[KORNOG_DATA] 🔍 Platform is Linux');
    baseDir = await getApplicationSupportDirectory();
    print('[KORNOG_DATA] ✅ Application support dir: ${baseDir.path}');
  } else if (Platform.isWindows) {
    print('[KORNOG_DATA] 🔍 Platform is Windows');
    baseDir = await getApplicationSupportDirectory();
  } else if (Platform.isMacOS) {
    print('[KORNOG_DATA] 🔍 Platform is macOS');
    baseDir = await getApplicationSupportDirectory();
  } else {
    throw UnsupportedError('Unsupported platform');
  }
  
  final kornogDir = Directory('${baseDir.path}/KornogData');
  print('[KORNOG_DATA] 📍 Chemin KornogData complet: ${kornogDir.path}');
  
  if (!(await kornogDir.exists())) {
    print('[KORNOG_DATA] ⚠️  Dossier n\'existe pas, création...');
    await kornogDir.create(recursive: true);
    print('[KORNOG_DATA] ✅ Dossier créé');
  } else {
    print('[KORNOG_DATA] ✅ Dossier existe déjà');
  }
  
  print('[KORNOG_DATA] ✅ READY: ${kornogDir.path}');
  print('[KORNOG_DATA] ════════════════════════════════════════');
  return kornogDir;
}

/// Fournit le dossier de stockage pour les fichiers GRIB, dans KornogData/grib
Future<Directory> getGribDataDirectory() async {
  print('[GRIB_DATA] ════════════════════════════════════════');
  print('[GRIB_DATA] 📂 ENTERING getGribDataDirectory');
  final kornogDir = await getKornogDataDirectory();
  final gribDir = Directory('${kornogDir.path}/grib');
  print('[GRIB_DATA] 📍 Chemin GRIB complet: ${gribDir.path}');
  
  if (!(await gribDir.exists())) {
    print('[GRIB_DATA] ⚠️  Dossier GRIB n\'existe pas, création...');
    await gribDir.create(recursive: true);
    print('[GRIB_DATA] ✅ Dossier GRIB créé');
  } else {
    print('[GRIB_DATA] ✅ Dossier GRIB existe déjà');
    // List contents
    try {
      final contents = gribDir.listSync();
      print('[GRIB_DATA] 📦 Fichiers dans le dossier: ${contents.length}');
      for (final item in contents.take(5)) {
        print('[GRIB_DATA]   - ${item.path}');
      }
    } catch (e) {
      print('[GRIB_DATA] ⚠️  Erreur listing: $e');
    }
  }
  
  print('[GRIB_DATA] ✅ READY: ${gribDir.path}');
  print('[GRIB_DATA] ════════════════════════════════════════');
  return gribDir;
}

/// Fournit le dossier de stockage pour les cartes, dans KornogData/maps
Future<Directory> getMapDataDirectory() async {
  print('[MAP_DATA] Entrée getMapDataDirectory');
  final kornogDir = await getKornogDataDirectory();
  final mapDir = Directory('${kornogDir.path}/maps');
  print('[MAP_DATA] Chemin maps: ${mapDir.path}');
  if (!(await mapDir.exists())) {
    print('[MAP_DATA] Création du dossier maps');
    await mapDir.create(recursive: true);
  }
  print('[MAP_DATA] Dossier maps prêt');
  return mapDir;
}

