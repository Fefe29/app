import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/data/datasources/gribs/grib_interpolation_service.dart';
import 'package:kornog/data/datasources/gribs/grib_overlay_providers.dart';
import 'package:kornog/features/charts/domain/services/screen_to_geo_service.dart';
import 'package:kornog/features/charts/presentation/models/view_transform.dart';

/// Provider pour obtenir le vent interpolé à une position pixel
/// 
/// Usage:
/// ```dart
/// final wind = ref.watch(windAtScreenPositionProvider(
///   pixelPos: Offset(100, 200),
///   view: view,
///   canvasSize: size,
/// ));
/// ```
final windAtScreenPositionProvider =
    FutureProvider.family<WindVector?, ScreenPositionParams>(
  (ref, params) async {
    final uGrids = ref.watch(currentGribUGridProvider);
    final vGrids = ref.watch(currentGribVGridProvider);

    if (uGrids == null || vGrids == null) {
      return null;
    }

    // Convertis pixel → géo
    final geo = ScreenToGeoService.pixelToGeo(
      params.pixelPos,
      params.view,
      params.canvasSize,
    );

    if (geo == null) return null;

    // Interpole le vent à cette position géographique
    return GribInterpolationService.interpolateWind(
      [uGrids],
      [vGrids],
      [DateTime.now()],
      geo.longitude,
      geo.latitude,
      DateTime.now(),
    );
  },
);

/// Paramètres pour la requête de vent à une position écran
class ScreenPositionParams {
  final Offset pixelPos;
  final ViewTransform view;
  final Size canvasSize;

  ScreenPositionParams({
    required this.pixelPos,
    required this.view,
    required this.canvasSize,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenPositionParams &&
          runtimeType == other.runtimeType &&
          pixelPos == other.pixelPos &&
          view == other.view &&
          canvasSize == other.canvasSize;

  @override
  int get hashCode =>
      pixelPos.hashCode ^ view.hashCode ^ canvasSize.hashCode;
}
