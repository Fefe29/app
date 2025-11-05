import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/data/datasources/gribs/grib_interpolation_service.dart';
import 'package:kornog/data/datasources/gribs/grib_overlay_providers.dart';
import 'package:kornog/domain/models/geographic_position.dart';

/// Provider pour interpoler le vent à une position/temps quelconque
/// 
/// Usage:
/// ```dart
/// final wind = ref.watch(
///   interpolatedWindProvider(
///     lon: 48.5,
///     lat: -4.5,
///     time: DateTime.now(),
///   )
/// );
/// ```
final interpolatedWindProvider = FutureProvider.family<WindVector?, InterpolationParams>(
  (ref, params) async {
    final uGrids = ref.watch(currentGribUGridProvider);
    final vGrids = ref.watch(currentGribVGridProvider);
    
    if (uGrids == null || vGrids == null) {
      return null;
    }

    // FIXME: Il faudrait stocker les timestamps quelque part
    // Pour l'instant on suppose que c'est le timestamp actuel
    final now = DateTime.now();
    
    return GribInterpolationService.interpolateWind(
      [uGrids],
      [vGrids],
      [now],
      params.lon,
      params.lat,
      params.time,
    );
  },
);

/// Paramètres pour l'interpolation du vent
class InterpolationParams {
  final double lon;
  final double lat;
  final DateTime time;

  InterpolationParams({
    required this.lon,
    required this.lat,
    required this.time,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InterpolationParams &&
          runtimeType == other.runtimeType &&
          lon == other.lon &&
          lat == other.lat &&
          time == other.time;

  @override
  int get hashCode => lon.hashCode ^ lat.hashCode ^ time.hashCode;
}

/// Provider pour interpoler le vent à une position géographique
final interpolatedWindAtPositionProvider = FutureProvider.family<
    WindVector?,
    ({GeographicPosition position, DateTime time})>(
  (ref, params) async {
    final uGrids = ref.watch(currentGribUGridProvider);
    final vGrids = ref.watch(currentGribVGridProvider);
    
    if (uGrids == null || vGrids == null) {
      return null;
    }

    return GribInterpolationService.interpolateWind(
      [uGrids],
      [vGrids],
      [DateTime.now()],
      params.position.longitude,
      params.position.latitude,
      params.time,
    );
  },
);
