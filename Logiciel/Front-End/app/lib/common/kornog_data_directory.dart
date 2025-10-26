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
