#!/usr/bin/env dart
import 'dart:io';
import 'lib/data/datasources/gribs/grib_downloader.dart';

Future<void> main() async {
  print('🧪 Test du GribDownloader avec les améliorations');
  print('==============================================\n');

  final outDir = Directory('/home/fefe/.local/share/kornog/KornogData/grib');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final downloader = GribDownloader();

  // Test simple: télécharger un seul fichier GFS
  final opts = GribDownloadOptions(
    model: GribModel.gfs025,
    cycleUtc: DateTime(2025, 11, 13, 12), // 2025-11-13 12:00 UTC
    days: 1,
    stepHours: 24,
    leftLon: -10.0,
    rightLon: 10.0,
    bottomLat: 40.0,
    topLat: 50.0,
    variables: const [GribVariable.wind10m],
    outDir: outDir,
  );

  print('📥 Lancement du téléchargement...');
  print('   Modèle: ${opts.model}');
  print('   Cycle: ${opts.cycleUtc}');
  print('   Sortie: ${opts.outDir.path}\n');

  try {
    final files = await downloader.download(opts);
    
    print('\n✅ Téléchargement terminé!');
    print('📊 Fichiers: ${files.length}');
    
    for (final f in files) {
      final size = await f.length();
      final fileName = f.path.split('/').last;
      print('  - $fileName: ${(size / 1024).toStringAsFixed(1)} KB');
      
      if (size == 0) {
        print('    ⚠️  ATTENTION: FICHIER VIDE!');
      }
    }
    
    // Lister les fichiers créés dans le répertoire
    print('\n📂 Fichiers dans ${outDir.path}:');
    await for (final entity in outDir.list(recursive: true)) {
      if (entity is File) {
        final size = await entity.length();
        final relative = entity.path.replaceFirst('${outDir.path}/', '');
        print('   $relative: ${(size / 1024).toStringAsFixed(1)} KB');
      }
    }
    
  } catch (e) {
    print('❌ Erreur: $e');
    print('📋 Stack trace:');
    print(StackTrace.current);
  }
}
