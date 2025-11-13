#!/usr/bin/env dart
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🧪 Test direct du téléchargement .anl');
  print('=================================\n');

  final url = Uri.parse(
    'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl'
    '?file=gfs.t12z.pgrb2.0p25.anl'
    '&subregion='
    '&leftlon=-10&rightlon=10&toplat=50&bottomlat=40'
    '&dir=/gfs.20251113/12/atmos'
    '&var_UGRD=on&var_VGRD=on'
  );

  print('📥 URL: ${url.path}\n');

  final res = await http.get(url);
  print('📊 HTTP Status: ${res.statusCode}');
  print('📏 Body size: ${res.bodyBytes.length} bytes\n');

  // Test writeAsBytes
  final file1 = File('/tmp/test_anl_writeasbytes.grib');
  print('📝 Test 1: writeAsBytes()');
  await file1.writeAsBytes(res.bodyBytes);
  print('   Écrit');
  var size1 = await file1.length();
  print('   Taille: $size1 bytes\n');

  // Test RandomAccessFile
  final file2 = File('/tmp/test_anl_raf.grib');
  print('📝 Test 2: RandomAccessFile.writeFrom()');
  final raf = file2.openSync();
  raf.writeFromSync(res.bodyBytes);
  raf.flushSync();
  raf.closeSync();
  print('   Écrit');
  var size2 = await file2.length();
  print('   Taille: $size2 bytes\n');

  // Vérifier
  print('✅ Résultat:');
  print('   writeAsBytes: $size1 bytes ${size1 > 0 ? "✅" : "❌"}');
  print('   RandomAccessFile: $size2 bytes ${size2 > 0 ? "✅" : "❌"}');
}
