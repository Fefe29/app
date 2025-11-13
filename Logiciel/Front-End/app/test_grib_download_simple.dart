#!/usr/bin/env dart
import 'dart:io';
import 'lib/data/datasources/gribs/grib_downloader.dart';

void main() async {
  print('🧪 Test téléchargement GRIB');
  print('================================\n');

  final downloader = GribDownloader();
  final outDir = Directory('/tmp/grib_test');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final opts = GribDownloadOptions(
    model: GribModel.gfs025,
    cycleUtc: DateTime.now().toUtc(),
    days: 1,
    stepHours: 6,
    leftLon: -10.0,
    rightLon: 10.0,
    bottomLat: 40.0,
    topLat: 50.0,
    variables: const [
      GribVariable.wind10m,
    ],
    outDir: outDir,
  );

  print('📥 Lancement du téléchargement...');
  try {
    final files = await downloader.download(opts);
    print('\n✅ Téléchargement terminé!');
    print('📊 Fichiers téléchargés: ${files.length}');
    for (final f in files) {
      final size = await f.length();
      print('  - ${f.path.split('/').last}: $size bytes');
    }
  } catch (e) {
    print('❌ Erreur: $e');
  }
}
