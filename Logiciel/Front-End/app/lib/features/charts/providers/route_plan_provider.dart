/// Routing / route plan providers.
/// See ARCHITECTURE_DOCS.md (section: route_plan_provider.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../domain/services/routing_calculator.dart';
import '../domain/services/wind_trend_analyzer.dart';
import 'course_providers.dart';
import 'polar_providers.dart';
import 'wind_trend_provider.dart';
import 'mercator_coordinate_system_provider.dart';
import '../../../common/providers/app_providers.dart';

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
  final mercatorService = ref.watch(mercatorCoordinateSystemProvider);
  
  // Calcul de l'angle optimal basé sur la force du vent
  final optimalFromWind = _calculateOptimalUpwindAngle(wind.speed);
  
  // Si on a une polaire chargée, on la privilégie, sinon on utilise le calcul VMG
  final upwind = vmc?.angleDeg ?? optimalFromWind;
  
  print('VMG OPTIMIZATION - TWS: ${wind.speed.toStringAsFixed(1)}nds → Optimal angle: ${optimalFromWind.toStringAsFixed(1)}°, VMC from polar: ${vmc?.angleDeg?.toStringAsFixed(1) ?? "NULL"}, Final: ${upwind.toStringAsFixed(1)}°');
  if (vmc != null) {
    print('VMG POLAR - Angle: ${vmc.angleDeg}°, Speed: ${vmc.speed.toStringAsFixed(1)}nds, VMG: ${vmc.vmg.toStringAsFixed(1)}nds');
  }
  
  return RoutingCalculator(
    mercatorService: mercatorService,
    windDirDeg: wind.directionDeg,
    windSpeed: wind.speed,
    optimalUpwindAngle: upwind,
    currentTwaSigned: twaSigned,
  );
});


class RoutePlanNotifier extends Notifier<RoutePlan> {
  Timer? _timer;
  bool _hasRouted = false;
  WindTrendSnapshot? _lastTrend;

  @override
  RoutePlan build() {
    // Initial state: empty route
    // Listen to wind trend and course
    ref.listen<WindTrendSnapshot>(windTrendSnapshotProvider, (prev, next) {
      _lastTrend = next;
      _maybeTriggerInitialRouting();
    });
    ref.listen(courseProvider, (prev, next) {
      // Si l'utilisateur change le parcours, on autorise un nouveau routage
      _hasRouted = false;
      state = RoutePlan([]);
      _maybeTriggerInitialRouting();
    });
    // On ne recalcule pas automatiquement sur changement de vent
    return RoutePlan([]);
  }

  void _maybeTriggerInitialRouting() {
    if (_hasRouted) return;
    final trend = _lastTrend;
    final course = ref.read(courseProvider);
    
    // Conditions minimales : avoir des données et des bouées
    if (trend == null || course.buoys.isEmpty) return;
    
    // Pour le routage automatique, on garde une exigence de fiabilité
    // mais on réduit le délai à 10s au lieu de 20s
    if (!trend.isReliable) return;
    if (trend.actualDataDurationSeconds < 10) {
      // Attendre 10s de données fiables pour le routage automatique
      _timer?.cancel();
      final toWait = 10.0 - trend.actualDataDurationSeconds;
      if (toWait > 0) {
        _timer = Timer(Duration(milliseconds: (toWait * 1000).round()), () {
          _maybeTriggerInitialRouting();
        });
      }
      return;
    }
    // Assez de données fiables, on calcule la route une seule fois
    print('ROUTE_PROVIDER - Routage automatique initial après ${trend.actualDataDurationSeconds}s de données');
    _computeRoute(trend);
    _hasRouted = true;
  }

  void reroute() {
    // Permet à l'utilisateur de forcer un nouveau routage
    print('ROUTE_PROVIDER - Début reroute manuel');
    final trend = ref.read(windTrendSnapshotProvider);
    final course = ref.read(courseProvider);
    
    print('ROUTE_PROVIDER - Trend: reliable=${trend.isReliable}, duration=${trend.actualDataDurationSeconds}s');
    print('ROUTE_PROVIDER - Course: ${course.buoys.length} bouées, startLine=${course.startLine != null}, finishLine=${course.finishLine != null}');
    
    // Vérification simplifiée : seulement les bouées sont nécessaires
    if (course.buoys.isEmpty) {
      print('ROUTE_PROVIDER - Échec reroute: aucune bouée définie');
      return;
    }
    
    // On accepte maintenant même des données non fiables pour le routage manuel
    if (!trend.isReliable) {
      print('ROUTE_PROVIDER - ATTENTION: Routage avec données vent non fiables');
    }
    if (trend.actualDataDurationSeconds < 20) {
      print('ROUTE_PROVIDER - ATTENTION: Routage avec durée données insuffisante (${trend.actualDataDurationSeconds}s < 20s)');
    }
    
    print('ROUTE_PROVIDER - Calcul de la route...');
    _computeRoute(trend);
    _hasRouted = true;
    print('ROUTE_PROVIDER - Reroute terminé');
  }

  void _computeRoute(WindTrendSnapshot trend) {
    final course = ref.read(courseProvider);
    final calc = ref.read(_routingCalculatorProvider);
    final result = calc.compute(course, windTrend: trend);
    state = result;
    // Log pour debug
    print('ROUTE_PROVIDER - Routage calculé: ${result.legs.length} segments');
    for (var i = 0; i < result.legs.length; i++) {
      final leg = result.legs[i];
      print('ROUTE_PROVIDER - Leg $i: (${leg.startX.toStringAsFixed(1)}, ${leg.startY.toStringAsFixed(1)}) → (${leg.endX.toStringAsFixed(1)}, ${leg.endY.toStringAsFixed(1)}) [${leg.label}]');
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

final routePlanProvider = NotifierProvider<RoutePlanNotifier, RoutePlan>(RoutePlanNotifier.new);
