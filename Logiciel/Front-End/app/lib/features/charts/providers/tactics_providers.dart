import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/ado_refus_strategy.dart';
import 'wind_simulation_provider.dart';

final adoRefusStrategyProvider = Provider<AdoRefusStrategy>((ref) {
  return AdoRefusStrategy(periodSeconds: 5, thresholdDeg: 2); // paramètres par défaut
});

/// Provider dérivé générant une recommandation d'amure en continu.
final tackRecommendationProvider = StreamProvider<TackRecommendation?>((ref) async* {
  final strategy = ref.watch(adoRefusStrategyProvider);
  final wind = ref.watch(unifiedWindProvider); // Rebuild 1Hz sur mise à jour vent unifié
  // On ne veut pas recréer la stratégie, seulement ingérer la nouvelle mesure.
  final rec = strategy.ingest(wind);
  yield rec;
});
