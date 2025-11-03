import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Fournit le dossier de stockage principal pour les cartes Kornog, organisé et robuste,
/// compatible Android, iOS, Linux, Windows, macOS.
Future<Directory> getKornogDataDirectory() async {
  print('[KORNOG_DATA] Entrée getKornogDataDirectory');
  Directory baseDir;
  if (Platform.isAndroid) {
    print('[KORNOG_DATA] Platform is Android, appel getApplicationDocumentsDirectory');
    baseDir = await getApplicationDocumentsDirectory();
    print('[KORNOG_DATA] getApplicationDocumentsDirectory OK: ${baseDir.path}');
  } else if (Platform.isIOS) {
    baseDir = await getApplicationDocumentsDirectory();
  } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    baseDir = await getApplicationSupportDirectory();
  } else {
    throw UnsupportedError('Unsupported platform');
  }
  final kornogDir = Directory('${baseDir.path}/KornogData');
  print('[KORNOG_DATA] Chemin KornogData: ${kornogDir.path}');
  if (!(await kornogDir.exists())) {
    print('[KORNOG_DATA] Création du dossier KornogData');
    await kornogDir.create(recursive: true);
  }
  print('[KORNOG_DATA] Dossier prêt');
  return kornogDir;
}

/// Fournit le dossier de stockage pour les fichiers GRIB, dans KornogData/grib
Future<Directory> getGribDataDirectory() async {
  print('[GRIB_DATA] Entrée getGribDataDirectory');
  final kornogDir = await getKornogDataDirectory();
  final gribDir = Directory('${kornogDir.path}/grib');
  print('[GRIB_DATA] Chemin grib: ${gribDir.path}');
  if (!(await gribDir.exists())) {
    print('[GRIB_DATA] Création du dossier grib');
    await gribDir.create(recursive: true);
  }
  print('[GRIB_DATA] Dossier grib prêt');
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
