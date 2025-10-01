import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/routing_calculator.dart';
import 'wind_trend_provider.dart';
import 'course_providers.dart';

final _routingCalculatorProvider = Provider<RoutingCalculator>((_) => RoutingCalculator());

final routePlanProvider = Provider<RoutePlan>((ref) {
  final course = ref.watch(courseProvider);
  final calc = ref.watch(_routingCalculatorProvider);
  final trend = ref.watch(windTrendSnapshotProvider); // direct snapshot
  return calc.compute(course, windTrend: trend);
});
