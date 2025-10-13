import 'dart:typed_data';

/// Grille scalaire régulière (lat/lon), rangée-major (y, puis x)
class ScalarGrid {
  final int nx, ny;
  final double lon0, lat0;   // coin bas-gauche (lon, lat)
  final double dlon, dlat;   // pas en degrés
  final Float32List values;  // longueur = nx*ny
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

  double valueAtIndex(int ix, int iy) {
    if (ix < 0 || ix >= nx || iy < 0 || iy >= ny) return double.nan;
    return values[iy * nx + ix];
  }

  /// Échantillonnage bilinéaire (lon/lat -> valeur)
  double sampleBilinear(double lon, double lat) {
    final fx = (lon - lon0) / dlon;
    final fy = (lat - lat0) / dlat;
    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;
    if (x0 < 0 || y0 < 0 || x1 >= nx || y1 >= ny) return double.nan;

    final dx = fx - x0;
    final dy = fy - y0;

    final v00 = valueAtIndex(x0, y0);
    final v10 = valueAtIndex(x1, y0);
    final v01 = valueAtIndex(x0, y1);
    final v11 = valueAtIndex(x1, y1);
    if (v00.isNaN || v10.isNaN || v01.isNaN || v11.isNaN) return double.nan;

    final v0 = v00 * (1 - dx) + v10 * dx;
    final v1 = v01 * (1 - dx) + v11 * dx;
    return v0 * (1 - dy) + v1 * dy;
  }
}
