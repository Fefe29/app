#!/usr/bin/env dart
import 'dart:io';
import 'lib/data/datasources/gribs/grib_downloader.dart';

void main() {
  print('Test _forecastHours:');
  
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
    outDir: Directory('/tmp'),
  );

  // Impossible d'accéder à _forecastHours car c'est private
  // Utilisons une autre approche - simuler le calcul
  final totalHours = opts.days * 24;
  final cap = totalHours;
  
  print('days: ${opts.days}');
  print('stepHours: ${opts.stepHours}');
  print('totalHours: $totalHours');
  print('cap: $cap');
  
  print('Heures générées:');
  for (int h = 0; h <= cap; h += opts.stepHours) {
    print('  - $h');
  }
}
