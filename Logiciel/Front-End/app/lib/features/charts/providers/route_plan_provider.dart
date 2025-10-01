import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/routing_calculator.dart';
import 'course_providers.dart';
import 'polar_providers.dart';
import 'package:kornog/common/providers/app_providers.dart';

final _routingCalculatorProvider = Provider<RoutingCalculator>((ref) {
  final wind = ref.watch(windSampleProvider);
  final vmc = ref.watch(vmcUpwindProvider);
  return RoutingCalculator(
    windDirDeg: wind.directionDeg,
    optimalUpwindAngle: vmc?.angleDeg,
  );
});

final routePlanProvider = Provider<RoutePlan>((ref) {
  final course = ref.watch(courseProvider);
  final calc = ref.watch(_routingCalculatorProvider);
  // TODO: réintroduire une analyse de tendance plus tard (supprimée avec wind_trend_provider)
  return calc.compute(course, windTrend: null);
});
