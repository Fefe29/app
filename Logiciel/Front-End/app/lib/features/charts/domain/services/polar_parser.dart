import 'dart:convert';

import '../models/polar_table.dart';

/// Parseur CSV très simple pour polaires (séparateur ';').
/// Hypothèse: première ligne => forces de vent (cellule [0][0] vide ou 0),
/// première colonne => angles.
class PolarParser {
  PolarTable parseFromCsvString(String csvContent) {
    final lines = const LineSplitter().convert(csvContent.trim());
    if (lines.isEmpty) {
      throw FormatException('Fichier vide');
    }
    final List<List<String>> raw = [];
    for (final l in lines) {
      if (l.trim().isEmpty) continue; // ignore lignes vides
      raw.add(l.split(';'));
    }
    if (raw.isEmpty) throw FormatException('Aucune donnée exploitable');

    // Normaliser largeur -> trouver max colonnes.
    final maxCols = raw.map((r) => r.length).fold<int>(0, (p, c) => c > p ? c : p);
    for (final r in raw) {
      if (r.length < maxCols) {
        r.addAll(List.filled(maxCols - r.length, ''));
      }
    }

    // Ligne 0 => vent
    final windSpeeds = <double>[];
    for (var j = 1; j < maxCols; j++) {
      windSpeeds.add(_toDoubleSafe(raw[0][j]));
    }

    final angles = <double>[];
    final speeds = <List<double>>[];
    for (var i = 1; i < raw.length; i++) {
      final row = raw[i];
      angles.add(_toDoubleSafe(row[0]));
      final line = <double>[];
      for (var j = 1; j < maxCols; j++) {
        line.add(_toDoubleSafe(row[j]));
      }
      speeds.add(line);
    }

    if (angles.isEmpty || windSpeeds.isEmpty) {
      throw FormatException('Angles ou forces de vent manquants');
    }

    return PolarTable(angles: angles, windSpeeds: windSpeeds, speeds: speeds);
  }

  double _toDoubleSafe(String v) {
    final t = v.trim();
    if (t.isEmpty) return 0.0; // MVP: valeur vide => 0
    return double.tryParse(t.replaceAll(',', '.')) ?? 0.0;
  }
}
