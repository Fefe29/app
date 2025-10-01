import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/ado_refus_strategy.dart';
import 'package:kornog/common/providers/app_providers.dart';

final adoRefusStrategyProvider = Provider<AdoRefusStrategy>((ref) {
  return AdoRefusStrategy(periodSeconds: 5, thresholdDeg: 2); // paramètres par défaut
});

/// Provider dérivé générant une recommandation d'amure en continu.
final tackRecommendationProvider = StreamProvider<TackRecommendation?>((ref) async* {
  final strategy = ref.watch(adoRefusStrategyProvider);
  final wind = ref.watch(windSampleProvider); // Source unique du vent via métriques
  // On ne veut pas recréer la stratégie, seulement ingérer la nouvelle mesure.
  final rec = strategy.ingest(wind);
  yield rec;
});
