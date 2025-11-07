import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'viewport_wind_grid.dart';
import 'grib_overlay_providers.dart';

// Import pour accéder à la ViewTransform actuelle
// TODO: Importer depuis le bon endroit après vérification de la structure

/// Provider qui génère les 10 points du viewport et récupère le vent
/// Dépend de:
/// - currentGribUGridProvider, currentGribVGridProvider (les grilles GRIB)
/// - gribForecastHourProvider (l'heure de prévision courante)
/// - La ViewTransform actuelle (zoom/pan) - TODO: faire passer depuis le widget
final viewportWindGridProvider = FutureProvider.family<List<WindPoint>, Map<String, dynamic>>((ref, params) async {
  // Extraire les paramètres
  final minLon = params['minLon'] as double;
  final maxLon = params['maxLon'] as double;
  final minLat = params['minLat'] as double;
  final maxLat = params['maxLat'] as double;
  final forecastTime = params['time'] as DateTime;

  // Récupérer les grilles GRIB
  final uGrid = ref.watch(currentGribUGridProvider);
  final vGrid = ref.watch(currentGribVGridProvider);

  if (uGrid == null || vGrid == null) {
    print('[VIEWPORT_GRID] No GRIB data available');
    return [];
  }

  // Générer les points et récupérer le vent
  final windPoints = await ViewportWindGrid.generateWindPoints(
    minLon: minLon,
    maxLon: maxLon,
    minLat: minLat,
    maxLat: maxLat,
    uGrids: [uGrid],
    vGrids: [vGrid],
    timestamps: [forecastTime], // TODO: gérer plusieurs timestamps
    forecastTime: forecastTime,
  );

  print('[VIEWPORT_GRID] Generated ${windPoints.length} wind points');
  return windPoints;
});

/// Notifier pour stocker les paramètres du viewport courant
class ViewportParamsNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() => {
    'minLon': -180.0,
    'maxLon': 180.0,
    'minLat': -85.0,
    'maxLat': 85.0,
    'time': DateTime.now(),
  };

  void setViewportBounds({
    required double minLon,
    required double maxLon,
    required double minLat,
    required double maxLat,
  }) {
    state = {
      ...state,
      'minLon': minLon,
      'maxLon': maxLon,
      'minLat': minLat,
      'maxLat': maxLat,
    };
  }

  void setForecastTime(DateTime time) {
    state = {
      ...state,
      'time': time,
    };
  }
}

final viewportParamsProvider = NotifierProvider<ViewportParamsNotifier, Map<String, dynamic>>(
  ViewportParamsNotifier.new,
);
