import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/polar_table.dart';
import '../domain/services/polar_parser.dart';
import '../domain/services/vmc_calculator.dart';
import 'package:kornog/common/providers/app_providers.dart';

/// Table de polaires chargée (Phase 1: aucune source -> null). Plus tard on lira un asset ou un fichier.
final polarTableProvider = FutureProvider<PolarTable?>((ref) async {
  final raw = await rootBundle.loadString('assets/polars/j80.csv');
  final parser = PolarParser();
  try {
    final table = parser.parseFromCsvString(raw);
    return table;
  } catch (e) {
    // En cas de parse raté, retourner null pour UI fallback.
    return null;
  }
});

/// Force du vent courante (TWS) extraite du snapshot télémétrie si disponible.
/// Pour l'instant on renvoie une valeur fictive jusqu'à branchement réel.
final currentWindSpeedProvider = Provider<double?>((ref) {
  final sample = ref.watch(windSampleProvider);
  return sample.speed;
});

/// Angle du vent courant (TWA) – placeholder.
final currentWindAngleProvider = Provider<double?>((ref) {
  final sample = ref.watch(windSampleProvider);
  return sample.directionDeg;
});

final _vmcCalculatorProvider = Provider<VmcCalculator>((_) => VmcCalculator());

/// Résultat VMC près selon polar + vent.
final vmcUpwindProvider = Provider<VmcResult?>((ref) {
  final tableAsync = ref.watch(polarTableProvider);
  final tws = ref.watch(currentWindSpeedProvider);
  final calc = ref.watch(_vmcCalculatorProvider);
  return tableAsync.maybeWhen(
    data: (table) {
      if (table == null || tws == null) return null;
      return calc.bestUpwind(table, tws);
    },
    orElse: () => null,
  );
});

/// Résultat VMC portant.
final vmcDownwindProvider = Provider<VmcResult?>((ref) {
  final tableAsync = ref.watch(polarTableProvider);
  final tws = ref.watch(currentWindSpeedProvider);
  final calc = ref.watch(_vmcCalculatorProvider);
  return tableAsync.maybeWhen(
    data: (table) {
      if (table == null || tws == null) return null;
      return calc.bestDownwind(table, tws);
    },
    orElse: () => null,
  );
});
