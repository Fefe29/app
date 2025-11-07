import 'dart:math' as math;
import 'package:kornog/data/datasources/gribs/grib_models.dart';

/// Service d'interpolation GRIB 3D (lon, lat, time)
/// Permet d'obtenir le vent n'importe où et n'importe quand, pas juste sur la grille
class GribInterpolationService {
  /// Interpole une valeur scalaire 3D dans le GRIB
  /// 
  /// [grids] - liste de grilles temporelles (t0, t1, ...)
  /// [timestamps] - timestamps correspondants
  /// [lon], [lat] - position géographique
  /// [time] - timestamp désiré
  /// [timeIndex] - index de temps dans [timestamps] (optionnel, pour perf)
  static double? interpolateScalar(
    List<ScalarGrid> grids,
    List<DateTime> timestamps,
    double lon,
    double lat,
    DateTime time, {
    int? timeIndex,
  }) {
    if (grids.isEmpty || timestamps.isEmpty) return null;
    if (grids.length != timestamps.length) return null;

    // Trouve les indices temporels pour interpolation
    final (int t0Idx, int t1Idx, double tAlpha) = _findTimeIndices(timestamps, time);
    if (t0Idx < 0 || t1Idx < 0) return null;

    // Interpole spatialement à t0 et t1
    final val0 = _interpolateSpatial(grids[t0Idx], lon, lat);
    if (val0 == null) return null;

    // Si t0 == t1, pas besoin d'interpoler temporellement
    if (t0Idx == t1Idx) return val0;

    final val1 = _interpolateSpatial(grids[t1Idx], lon, lat);
    if (val1 == null) return null;

    // Interpole temporellement
    return val0 * (1 - tAlpha) + val1 * tAlpha;
  }

  /// Interpole un vecteur (U, V) du vent 3D
  /// Retourne (u, v, vitesse, direction)
  static WindVector? interpolateWind(
    List<ScalarGrid> uGrids,
    List<ScalarGrid> vGrids,
    List<DateTime> timestamps,
    double lon,
    double lat,
    DateTime time,
  ) {
    final u = interpolateScalar(uGrids, timestamps, lon, lat, time);
    final v = interpolateScalar(vGrids, timestamps, lon, lat, time);

    if (u == null || v == null) {
      if (u == null || v == null) {
        print('[INTERP] Wind null at ($lon, $lat): u=$u, v=$v');
      }
      return null;
    }

    // Calcule vitesse et direction
    final speed = math.sqrt(u * u + v * v);
    final directionRad = math.atan2(u, v); // atan2(East, North) → direction
    final directionDeg = (directionRad * 180 / math.pi + 360) % 360;

    return WindVector(
      u: u,
      v: v,
      speed: speed,
      direction: directionDeg,
    );
  }

  /// Interpole spatialement une grille GRIB (bilinéaire)
  static double? _interpolateSpatial(ScalarGrid grid, double lon, double lat) {
    // Convertis lon/lat en indices de grille
    final x = (lon - grid.lon0) / grid.dlon;
    final y = (lat - grid.lat0) / grid.dlat;

    // Hors de la grille?
    if (x < 0 || x >= grid.nx - 1 || y < 0 || y >= grid.ny - 1) {
      return null;
    }

    // Indices des 4 coins de la cellule
    final x0 = x.floor();
    final x1 = x0 + 1;
    final y0 = y.floor();
    final y1 = y0 + 1;

    // Facteurs d'interpolation
    final fx = x - x0;
    final fy = y - y0;

    // Récupère les 4 valeurs
    final v00 = _getGridValue(grid, x0, y0);
    final v10 = _getGridValue(grid, x1, y0);
    final v01 = _getGridValue(grid, x0, y1);
    final v11 = _getGridValue(grid, x1, y1);

    if (v00 == null || v10 == null || v01 == null || v11 == null) {
      return null;
    }

    // Bilinéaire: interpole horizontalement puis verticalement
    final v0 = v00 * (1 - fx) + v10 * fx;
    final v1 = v01 * (1 - fx) + v11 * fx;
    final result = v0 * (1 - fy) + v1 * fy;

    return result;
  }

  /// Récupère une valeur de grille avec gestion des NaN/limites
  static double? _getGridValue(ScalarGrid grid, int x, int y) {
    if (x < 0 || x >= grid.nx || y < 0 || y >= grid.ny) {
      return null;
    }

    final idx = y * grid.nx + x;
    if (idx < 0 || idx >= grid.values.length) {
      return null;
    }

    final val = grid.values[idx];
    return val.isFinite ? val : null;
  }

  /// Trouve les indices temporels pour interpolation
  /// Retourne (t0Idx, t1Idx, alpha) où:
  ///   - alpha = 0 → 100% t0
  ///   - alpha = 1 → 100% t1
  ///   - alpha = 0.5 → 50% t0 + 50% t1
  static (int, int, double) _findTimeIndices(
    List<DateTime> timestamps,
    DateTime time,
  ) {
    // Si avant le premier timestamp
    if (time.compareTo(timestamps.first) < 0) {
      return (0, 0, 0.0);
    }

    // Si après le dernier timestamp
    if (time.compareTo(timestamps.last) > 0) {
      final idx = timestamps.length - 1;
      return (idx, idx, 0.0);
    }

    // Cherche les deux timestamps qui encadrent time
    for (int i = 0; i < timestamps.length - 1; i++) {
      final t0 = timestamps[i];
      final t1 = timestamps[i + 1];

      if (time.compareTo(t0) > 0 && time.compareTo(t1) < 0) {
        final totalDuration = t1.difference(t0).inMilliseconds;
        final elapsedDuration = time.difference(t0).inMilliseconds;
        final alpha = elapsedDuration / totalDuration;
        return (i, i + 1, alpha);
      }

      if (time == t0) {
        return (i, i, 0.0);
      }
    }

    // Dernier timestamp exactement
    final idx = timestamps.length - 1;
    return (idx, idx, 0.0);
  }

  /// ============================================================
  /// API PUBLIQUE POUR LE ROUTAGE
  /// ============================================================
  /// Récupère le vent à un point géographique pour un temps donné
  /// À utiliser pour le calcul de routage: pour chaque point de la trajectoire,
  /// récupérer le vent et l'inclure dans l'optimisation
  /// 
  /// Exemple:
  /// ```dart
  /// final wind = GribInterpolationService.getWindAt(
  ///   uGrids: gridsU, vGrids: gridsV, timestamps: times,
  ///   longitude: 7.5, latitude: 43.5,
  ///   time: DateTime.now()
  /// );
  /// if (wind != null) {
  ///   print('Vent: ${wind.speed} m/s, direction: ${wind.direction}°');
  /// }
  /// ```
  static WindVector? getWindAt({
    required List<ScalarGrid> uGrids,
    required List<ScalarGrid> vGrids,
    required List<DateTime> timestamps,
    required double longitude,
    required double latitude,
    required DateTime time,
  }) {
    return interpolateWind(uGrids, vGrids, timestamps, longitude, latitude, time);
  }

  /// Version batch: récupère le vent pour plusieurs points à la fois
  /// Utile pour interpoler une trajectoire entière
  static List<WindVector?> getWindAtMultiplePoints({
    required List<ScalarGrid> uGrids,
    required List<ScalarGrid> vGrids,
    required List<DateTime> timestamps,
    required List<(double lon, double lat)> points,
    required DateTime time,
  }) {
    return [
      for (final (lon, lat) in points)
        interpolateWind(uGrids, vGrids, timestamps, lon, lat, time),
    ];
  }
}

/// Résultat d'interpolation du vent
class WindVector {
  final double u; // Composante East (m/s)
  final double v; // Composante North (m/s)
  final double speed; // Vitesse en m/s
  final double direction; // Direction en degrés (0-360, 0=N, 90=E, 180=S, 270=W)

  WindVector({
    required this.u,
    required this.v,
    required this.speed,
    required this.direction,
  });

  @override
  String toString() =>
      'Wind(${speed.toStringAsFixed(1)} m/s @ ${direction.toStringAsFixed(0)}°)';
}

/// Extension helper pour DateTime
extension DateTimeComparison on DateTime {
  bool isBeforeDateTime(DateTime other) => isBefore(other);
  bool isAfterDateTime(DateTime other) => isAfter(other);
}

