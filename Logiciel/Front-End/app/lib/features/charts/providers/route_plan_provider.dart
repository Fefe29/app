/// Routing / route plan providers.
/// See ARCHITECTURE_DOCS.md (section: route_plan_provider.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/routing_calculator.dart';
import 'course_providers.dart';
import 'polar_providers.dart';
import 'package:kornog/common/providers/app_providers.dart';
import 'polar_providers.dart';

/// Calcule l'angle de remontée optimal selon la force du vent
/// Plus le vent est fort, plus on peut serrer le vent (VMG optimal)
double _calculateOptimalUpwindAngle(double windSpeedKnots) {
  // Courbe d'optimisation basée sur la théorie VMG
  // Vent faible: on doit abattre plus pour avoir de la vitesse
  // Vent fort: on peut serrer plus car la vitesse est suffisante
  if (windSpeedKnots <= 6) {
    // Petit temps: 45-50° pour garder la vitesse
    return 45.0 + (6 - windSpeedKnots) * 0.8; // Max 50° à 0 nds
  } else if (windSpeedKnots <= 12) {
    // Vent modéré: transition linéaire 45° → 35°
    return 45.0 - (windSpeedKnots - 6) * 1.67; // 45° à 6nds, 35° à 12nds
  } else if (windSpeedKnots <= 20) {
    // Vent fort: on peut serrer, 35° → 30°
    return 35.0 - (windSpeedKnots - 12) * 0.625; // 35° à 12nds, 30° à 20nds
  } else {
    // Vent très fort: limite à 30° minimum
    return 30.0;
  }
}

final _routingCalculatorProvider = Provider<RoutingCalculator>((ref) {
  final wind = ref.watch(windSampleProvider); // fournit TWD et TWS
  final vmc = ref.watch(vmcUpwindProvider);
  final twaSigned = ref.watch(metricProvider('wind.twa')).maybeWhen(data: (m) => m.value, orElse: () => null);
  
  // Calcul de l'angle optimal basé sur la force du vent
  final optimalFromWind = _calculateOptimalUpwindAngle(wind.speed);
  
  // Si on a une polaire chargée, on la privilégie, sinon on utilise le calcul VMG
  final upwind = vmc?.angleDeg ?? optimalFromWind;
  
  print('VMG OPTIMIZATION - TWS: ${wind.speed.toStringAsFixed(1)}nds → Optimal angle: ${optimalFromWind.toStringAsFixed(1)}°, Final: ${upwind.toStringAsFixed(1)}°');
  
  return RoutingCalculator(
    windDirDeg: wind.directionDeg,
    optimalUpwindAngle: upwind,
    currentTwaSigned: twaSigned,
  );
});

final routePlanProvider = Provider<RoutePlan>((ref) {
  final course = ref.watch(courseProvider);
  final calc = ref.watch(_routingCalculatorProvider);
  
  print('ROUTE_PROVIDER - Recalcul du routage déclenché');
  print('ROUTE_PROVIDER - Wind: ${calc.windDirDeg}°, Optimal upwind: ${calc.optimalUpwindAngle}°');
  print('ROUTE_PROVIDER - Course: ${course.buoys.length} bouées, startLine: ${course.startLine != null}');
  
  // TODO: réintroduire une analyse de tendance plus tard (supprimée avec wind_trend_provider)
  final result = calc.compute(course, windTrend: null);
  
  print('ROUTE_PROVIDER - Routage calculé: ${result.legs.length} segments');
  for (var i = 0; i < result.legs.length; i++) {
    final leg = result.legs[i];
    print('ROUTE_PROVIDER - Leg $i: (${leg.startX.toStringAsFixed(1)}, ${leg.startY.toStringAsFixed(1)}) → (${leg.endX.toStringAsFixed(1)}, ${leg.endY.toStringAsFixed(1)}) [${leg.label}]');
  }
  
  return result;
});
