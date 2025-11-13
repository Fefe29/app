#!/usr/bin/env dart
import 'dart:io';

void main() {
  print('🧪 Vérification des répertoires GRIB');
  print('================================\n');

  final gribDir = Directory('/home/fefe/.local/share/kornog/KornogData/grib');
  print('📁 Répertoire principal: ${gribDir.path}');
  print('   Existe: ${gribDir.existsSync()}');
  print('   Accessible: ${gribDir.existsSync()}\n');

  if (gribDir.existsSync()) {
    // Permissions
    try {
      final stat = gribDir.statSync();
      print('🔐 Permissions: ${stat.mode}');
    } catch (e) {
      print('❌ Impossible de lire les permissions: $e');
    }

    // Essayer de créer un fichier de test
    final testDir = Directory('${gribDir.path}/GFS_0p25/20251113T12');
    print('\n📁 Création du test répertoire: ${testDir.path}');
    
    try {
      testDir.createSync(recursive: true);
      print('✅ Répertoire créé');
      
      final testFile = File('${testDir.path}/test.txt');
      print('📝 Écriture d\'un fichier de test...');
      
      testFile.writeAsStringSync('test');
      print('✅ Fichier écrit');
      
      final exists = testFile.existsSync();
      print('✅ Vérification: fichier existe = $exists');
      
      final size = testFile.lengthSync();
      print('✅ Taille du fichier: $size bytes');
      
      testFile.deleteSync();
      print('✅ Fichier de test supprimé');
      
    } catch (e) {
      print('❌ ERREUR: $e');
    }
  }
}
