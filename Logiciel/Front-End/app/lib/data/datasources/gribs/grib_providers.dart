/// Providers pour la gestion des fichiers GRIB
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/kornog_data_directory.dart';

/// Provider pour le répertoire de stockage des fichiers GRIB
final gribStorageDirectoryProvider = FutureProvider<String>((ref) async {
  print('[GRIB_PROVIDER] gribStorageDirectoryProvider: début');
  final gribDir = await getGribDataDirectory();
  print('[GRIB_PROVIDER] gribStorageDirectoryProvider: ${gribDir.path}');
  return gribDir.path;
});
