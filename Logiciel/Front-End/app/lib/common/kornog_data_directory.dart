import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Fournit le dossier de stockage principal pour les cartes Kornog, organisé et robuste,
/// compatible Android, iOS, Linux, Windows, macOS.
Future<Directory> getKornogDataDirectory() async {
  Directory baseDir;
  if (Platform.isAndroid) {
    baseDir = (await getExternalStorageDirectory())!;
  } else if (Platform.isIOS) {
    baseDir = await getApplicationDocumentsDirectory();
  } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    baseDir = await getApplicationSupportDirectory();
  } else {
    throw UnsupportedError('Unsupported platform');
  }
  final kornogDir = Directory('${baseDir.path}/KornogData');
  if (!(await kornogDir.exists())) {
    await kornogDir.create(recursive: true);
  }
  return kornogDir;
}
