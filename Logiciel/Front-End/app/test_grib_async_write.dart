#!/usr/bin/env dart
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🧪 Test minimal de writeAsBytes avec NOMADS');

  final url = Uri.parse(
    'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl'
    '?file=gfs.t12z.pgrb2.0p25.anl'
    '&subregion=&leftlon=-10&rightlon=10&toplat=50&bottomlat=40'
    '&dir=/gfs.20251113/12/atmos&var_UGRD=on&var_VGRD=on'
  );

  try {
    print('📡 Téléchargement...');
    final res = await http.get(url);
    print('📊 Reçu: ${res.bodyBytes.length} bytes\n');

    final file = File('/tmp/test_write_async.grib');
    print('💾 Écriture via writeAsBytes...');
    
    await file.writeAsBytes(res.bodyBytes);
    
    print('✅ Écriture complète');
    
    final size = await file.length();
    print('📏 Taille vérifiée: $size bytes');
    
    if (size == 0) {
      print('❌ FICHIER VIDE APRÈS ÉCRITURE!');
      print('   Contenu attendu: ${res.bodyBytes.length} bytes');
    } else if (size != res.bodyBytes.length) {
      print('⚠️  Taille mismatch: attendu ${res.bodyBytes.length}, écrit $size');
    } else {
      print('✅ SUCCÈS: Fichier valide');
    }
  } catch (e) {
    print('❌ EXCEPTION: $e');
  }
}
