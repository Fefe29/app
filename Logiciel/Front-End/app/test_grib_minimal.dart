#!/usr/bin/env dart
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🧪 Test minimal de téléchargement GRIB');
  print('================================\n');

  // URL NOMADS GFS
  final url = Uri.parse(
    'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl'
    '?file=gfs.t12z.pgrb2.0p25.f000'
    '&subregion='
    '&leftlon=-10&rightlon=10&toplat=50&bottomlat=40'
    '&dir=/gfs.20251113/12/atmos'
    '&var_UGRD=on&var_VGRD=on'
  );

  print('📥 URL: $url\n');

  try {
    print('📡 Envoi de la requête...');
    final res = await http.get(url);
    
    print('📊 Réponse HTTP: ${res.statusCode}');
    print('📏 Taille du corps: ${res.bodyBytes.length} bytes\n');
    
    if (res.statusCode == 200) {
      final outDir = Directory('/tmp/grib_manual_test');
      outDir.createSync(recursive: true);
      
      final file = File('${outDir.path}/test_grib.grib2');
      print('💾 Écriture vers: ${file.path}');
      
      await file.writeAsBytes(res.bodyBytes);
      
      final writtenSize = await file.length();
      print('✅ Fichier écrit: $writtenSize bytes');
      
      if (writtenSize > 0) {
        print('✅ SUCCÈS: Fichier GRIB valide!');
      } else {
        print('❌ ERREUR: Fichier écrit mais vide!');
      }
    } else {
      print('❌ HTTP error: ${res.statusCode}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
