import 'dart:typed_data';
import 'dart:math' as math;

/// Grille scalaire régulière (lat/lon), rangée-major (y, puis x)
/// Représente une variable météo dans une grille régulière
class ScalarGrid {
  final int nx, ny;
  final double lon0, lat0;   // coin bas-gauche (lon, lat)
  final double dlon, dlat;   // pas en degrés
  final Float32List values;  // longueur = nx*ny, row-major order (y*nx + x)
  final double nodata;

  ScalarGrid({
    required this.nx,
    required this.ny,
    required this.lon0,
    required this.lat0,
    required this.dlon,
    required this.dlat,
    required this.values,
    this.nodata = double.nan,
  });

  /// Accès direct à la valeur à l'indice (ix, iy)
  double valueAtIndex(int ix, int iy) {
    if (ix < 0 || ix >= nx || iy < 0 || iy >= ny) return double.nan;
    return values[iy * nx + ix];
  }

  /// Lon/Lat depuis indice
  double lonFromIndex(int ix) => lon0 + ix * dlon;
  double latFromIndex(int iy) => lat0 + iy * dlat;

  /// Indice depuis lon/lat (sans interpolation)
  int? indexFromLon(double lon) {
    if (dlon == 0) return null;
    final i = ((lon - lon0) / dlon).round();
    return (i >= 0 && i < nx) ? i : null;
  }

  int? indexFromLat(double lat) {
    if (dlat == 0) return null;
    final j = ((lat - lat0) / dlat).round();
    return (j >= 0 && j < ny) ? j : null;
  }

  /// Interpolation bilinéaire (lon/lat -> valeur)
  double sampleAtLatLon(double lat, double lon) {
    if (dlon == 0 || dlat == 0) return double.nan;

    final ix = (lon - lon0) / dlon;
    final iy = (lat - lat0) / dlat;

    final iix = ix.floor();
    final jiy = iy.floor();

    if (iix < 0 || iix >= nx - 1 || jiy < 0 || jiy >= ny - 1) {
      return double.nan;
    }

    final dx = ix - iix;
    final dy = iy - jiy;

    final v00 = valueAtIndex(iix, jiy);
    final v10 = valueAtIndex(iix + 1, jiy);
    final v01 = valueAtIndex(iix, jiy + 1);
    final v11 = valueAtIndex(iix + 1, jiy + 1);

    if (v00.isNaN || v10.isNaN || v01.isNaN || v11.isNaN) {
      return double.nan;
    }

    final v0 = v00 * (1 - dx) + v10 * dx;
    final v1 = v01 * (1 - dx) + v11 * dx;
    return v0 * (1 - dy) + v1 * dy;
  }

  /// Récupère les bornes (min/max) de la grille en ignorant NaN
  (double, double) getValueBounds() {
    double vmin = double.infinity;
    double vmax = double.negativeInfinity;

    for (final v in values) {
      if (!v.isNaN) {
        if (v < vmin) vmin = v;
        if (v > vmax) vmax = v;
      }
    }

    if (vmin.isInfinite || vmax.isInfinite) {
      return (0.0, 1.0);
    }
    return (vmin, vmax);
  }

  /// Génère une grille régulière interpolée avec un nombre de vecteurs cible
  /// Retourne une liste de points (lon, lat) où les vecteurs seront affichés
  /// Si targetVectorCount = 20, génère ~20 points uniformément espacés
  List<(double lon, double lat)> generateInterpolatedGridPoints({
    required int targetVectorCount,
    double minLon = -180,
    double maxLon = 180,
    double minLat = -90,
    double maxLat = 90,
  }) {
    if (targetVectorCount <= 0) return [];

    // Pour un nombre N de vecteurs, on génère une grille de sqrt(N) × sqrt(N)
    // Sauf si ça résulterait en un nombre trop grand, on limite
    // CORRECTION: générer exactement targetVectorCount points (ou proche)
    final pointsPerSide = (math.sqrt(targetVectorCount.toDouble())).ceil();
    final actualCount = pointsPerSide * pointsPerSide;
    
    // Limiter aux bounds réels de la grille si nécessaire
    final actualMinLon = math.max(minLon, lon0);
    final actualMaxLon = math.min(maxLon, lon0 + (nx - 1) * dlon);
    final actualMinLat = math.max(minLat, lat0);
    final actualMaxLat = math.min(maxLat, lat0 + (ny - 1) * dlat);

    final points = <(double, double)>[];

    for (int i = 0; i < pointsPerSide; i++) {
      // Interpoler entre minLon et maxLon
      final t_lon = pointsPerSide > 1 ? i / (pointsPerSide - 1) : 0.5;
      final lon = actualMinLon + (actualMaxLon - actualMinLon) * t_lon;
      
      for (int j = 0; j < pointsPerSide; j++) {
        // Interpoler entre minLat et maxLat
        final t_lat = pointsPerSide > 1 ? j / (pointsPerSide - 1) : 0.5;
        final lat = actualMinLat + (actualMaxLat - actualMinLat) * t_lat;
        
        points.add((lon, lat));
      }
    }

    return points;
  }
}

/// Palette de couleurs pour les gribs
class ColorMap {
  /// Couleur bleu (froid) vers rouge (chaud)
  static const String blueToRed = 'blueToRed';

  /// Couleur vert (bas) vers jaune vers rouge (haut)
  static const String greenYellowRed = 'greenYellowRed';

  /// Bleu (très bas) -> vert -> jaune -> rouge (très haut)
  static const String parula = 'parula';

  static final Map<String, List<int>> _cmaps = {
    blueToRed: [
      0xFF0000FF, // blue
      0xFF0080FF,
      0xFF00FFFF,
      0xFF00FF80,
      0xFF00FF00,
      0xFF80FF00,
      0xFFFFFF00,
      0xFFFF8000,
      0xFFFF0000, // red
    ],
    greenYellowRed: [
      0xFF00AA00, // green
      0xFF55FF00,
      0xFFFFFF00, // yellow
      0xFFFFAA00,
      0xFFFF0000, // red
    ],
    parula: [
      0xFF0D0887,
      0xFF3B049F,
      0xFF5D04B8,
      0xFF1F77B4,
      0xFF1ABC9C,
      0xFF2ECC71,
      0xFFFFFF00,
      0xFFFF8C00,
      0xFFE74C3C,
      0xFF8B0000,
    ],
  };

  static int colorAt(String mapName, double t) {
    final cmap = _cmaps[mapName] ?? _cmaps[blueToRed]!;
    final clamped = t.clamp(0.0, 1.0);
    final idx = (clamped * (cmap.length - 1)).round();
    return cmap[idx];
  }
}
