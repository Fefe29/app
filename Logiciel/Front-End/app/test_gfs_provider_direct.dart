#!/usr/bin/env dart
import 'dart:io';
import 'lib/data/datasources/gribs/grib_downloader.dart';

void main() async {
  print('Test direct _GfsProvider');
  
  // Accès direct au provider pour vérifier
  final outDir = Directory('/home/fefe/.local/share/kornog/KornogData/grib');
  outDir.createSync(recursive: true);

  final opts = GribDownloadOptions(
    model: GribModel.gfs025,
    cycleUtc: DateTime(2025, 11, 13, 12),
    days: 1,
    stepHours: 24,
    leftLon: -10.0,
    rightLon: 10.0,
    bottomLat: 40.0,
    topLat: 50.0,
    variables: const [GribVariable.wind10m],
    outDir: outDir,
  );

  // Créer un test marker
  File('/tmp/test_gfs_provider_start.txt').writeAsStringSync('START\n');

  print('Téléchargement...');
  final downloader = GribDownloader();
  final files = await downloader.download(opts);

  File('/tmp/test_gfs_provider_end.txt').writeAsStringSync('END\n');

  print('Fichiers: ${files.length}');
  for (final f in files) {
    final size = await f.length();
    print('  - ${f.path.split('/').last}: $size bytes');
  }
}
