/// Transposition minimaliste de `polaire.py` en Dart.
/// Objectif: fournir des fonctions équivalentes pour charger la table de polaires
/// via le parseur déjà existant (`PolarParser`).
/// \n
import 'package:flutter/services.dart' show rootBundle;

import '../models/polar_table.dart';
import 'polar_parser.dart';

/// Emplacement par défaut (asset) des polaires du J80.
/// Equivalent conceptuel de `default_polar_path()` en Python.
const String kDefaultPolarAssetPath = 'assets/polars/j80.csv';

/// Charge les polaires par défaut depuis l'asset.
/// Retourne `null` si le chargement ou le parsing échoue (même philosophie que le code Python
/// qui retournait `None` et loggait un message).
Future<PolarTable?> loadDefaultPolars() async {
  try {
    final raw = await rootBundle.loadString(kDefaultPolarAssetPath);
    return PolarParser().parseFromCsvString(raw);
  } catch (e) {
    // On reste silencieux côté UI pour l'instant, simple trace console.
    // (Plus tard: remonter une exception métier ou logger structuré.)
    // ignore: avoid_print
    print('Echec chargement polaires défaut: $e');
    return null;
  }
}

/// Parse une chaîne CSV (séparateur ';') en `PolarTable`.
/// Renvoie `null` si parsing impossible (au lieu d'exceptions non attrapées côté appelant).
PolarTable? parsePolarsCsv(String csvContent) {
  try {
    return PolarParser().parseFromCsvString(csvContent);
  } catch (_) {
    return null;
  }
}
