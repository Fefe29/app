#!/usr/bin/env dart
import 'package:http/http.dart' as http;

void main() async {
  print('🧪 Comparaison des fichiers GFS');
  print('==================================\n');

  final baseUrl = 'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl';
  
  // Paramètres communs
  final params = '?subregion=&leftlon=-10&rightlon=10&toplat=50&bottomlat=40&dir=/gfs.20251113/12/atmos&var_UGRD=on&var_VGRD=on';

  // Test fichier .anl
  print('📥 Test 1: Fichier .anl');
  final urlAnl = Uri.parse('$baseUrl${params.replaceFirst('?', '?file=gfs.t12z.pgrb2.0p25.anl&')}');
  print('   URL: ${urlAnl.toString().substring(0, 80)}...');
  final resAnl = await http.get(urlAnl);
  print('   Status: ${resAnl.statusCode}');
  print('   Size: ${resAnl.bodyBytes.length} bytes\n');

  // Test fichier f024
  print('📥 Test 2: Fichier f024');
  final urlF024 = Uri.parse('$baseUrl${params.replaceFirst('?', '?file=gfs.t12z.pgrb2.0p25.f024&')}');
  print('   URL: ${urlF024.toString().substring(0, 80)}...');
  final resF024 = await http.get(urlF024);
  print('   Status: ${resF024.statusCode}');
  print('   Size: ${resF024.bodyBytes.length} bytes\n');

  // Vérifier si les premiers bytes sont du GRIB
  print('🔍 Vérification des signatures GRIB:');
  print('   .anl commence par: ${_hexDump(resAnl.bodyBytes.take(4).toList())}');
  print('   f024 commence par: ${_hexDump(resF024.bodyBytes.take(4).toList())}');
}

String _hexDump(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}
