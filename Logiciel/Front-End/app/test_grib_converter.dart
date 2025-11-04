#!/usr/bin/env dart
/// Test simple pour vérifier que GribConverter fonctionne avec les vrais fichiers GRIB
import 'dart:io';
import 'lib/data/datasources/gribs/grib_models.dart';

void main() async {
  print('🧪 TEST GRIB CONVERTER');
  print('================================\n');

  // Fichier GRIB réel
  final gribFile = File('/home/fefe/.local/share/kornog/KornogData/grib/GFS_0p25/20251103T12/gfs.t12z.pgrb2.0p25.f006');
  
  print('📁 Fichier: ${gribFile.path}');
  print('📊 Existe: ${gribFile.existsSync()}');
  if (gribFile.existsSync()) {
    final size = await gribFile.length();
    print('📏 Taille: $size bytes\n');
  }

  // Test: appel direct au script Python
  print('🔍 Test 1: Appel direct au script Python');
  print('-' * 40);
  
  final result = await Process.run(
    'python3',
    ['lib/data/datasources/gribs/parse_grib.py', gribFile.path, 'U'],
    runInShell: false,
  );

  if (result.exitCode == 0) {
    print('✅ Script exécuté avec succès');
    final lines = (result.stdout as String).split('\n').where((l) => l.isNotEmpty).toList();
    print('📈 Lignes CSV extraites: ${lines.length}');
    print('\n📋 Premières lignes:');
    for (final line in lines.take(5)) {
      print('   $line');
    }
  } else {
    print('❌ Erreur script');
    print('STDERR: ${result.stderr}');
  }

  print('\n✨ Test terminé');
}
