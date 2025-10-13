import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../features/charts/providers/mercator_coordinate_system_provider.dart';
import '../../../features/charts/domain/models/geographic_position.dart';
import '../../../features/charts/providers/coordinate_system_provider.dart'; // pour LocalPosition
import 'grib_overlay_models.dart';

typedef ColorMap = Color Function(double v);

ColorMap makeLinearColormap({
  required double vmin,
  required double vmax,
  required List<Color> stops,
}) {
  assert(stops.length >= 2);
  return (double v) {
    if (v.isNaN) return Colors.transparent;
    final t = ((v - vmin) / (vmax - vmin)).clamp(0.0, 1.0);
    final seg = (stops.length - 1);
    final x = t * seg;
    final i = x.floor().clamp(0, seg - 1);
    final f = x - i;
    final c0 = stops[i];
    final c1 = stops[i + 1];
    return Color.lerp(c0, c1, f)!;
  };
}

/// Peint la grille GRIB comme rectangles semi-transparents par-dessus la carte
class GribRasterPainter extends CustomPainter {
  final ScalarGrid grid;
  final MercatorCoordinateSystemService mercator;
  final double opacity;       // 0..1
  final ColorMap colormap;
  final int samplingStride;   // échantillonnage (1 = chaque cellule, 2 = 1 sur 2, etc.)

  GribRasterPainter({
    required this.grid,
    required this.mercator,
    required this.opacity,
    required this.colormap,
    this.samplingStride = 2,
  });

  static const double margin = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Mapping "local -> écran" cohérent avec _CoursePainter
    final bounds = _estimateLocalBounds();
    final availW = size.width - 2 * margin;
    final availH = size.height - 2 * margin;
    final spanX = bounds.maxX - bounds.minX;
    final spanY = bounds.maxY - bounds.minY;
    final scale = math.min(availW / spanX, availH / spanY);
    final offsetX = (size.width - spanX * scale) / 2;
    final offsetY = (size.height - spanY * scale) / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int jy = 0; jy < grid.ny - 1; jy += samplingStride) {
      for (int ix = 0; ix < grid.nx - 1; ix += samplingStride) {
        // cellule lon/lat
        final lon0 = grid.lon0 + ix * grid.dlon;
        final lat0 = grid.lat0 + jy * grid.dlat;
        final lon1 = lon0 + grid.dlon * samplingStride;
        final lat1 = lat0 + grid.dlat * samplingStride;

        // 4 coins en local via mercator.toLocal(GeographicPosition)
        final p00 = mercator.toLocal(GeographicPosition(latitude: lat0, longitude: lon0));
        final p11 = mercator.toLocal(GeographicPosition(latitude: lat1, longitude: lon1));

        // local -> écran (inversion Y)
        final x0 = offsetX + (p00.x - bounds.minX) * scale;
        final y0 = size.height - offsetY - (p00.y - bounds.minY) * scale;
        final x1 = offsetX + (p11.x - bounds.minX) * scale;
        final y1 = size.height - offsetY - (p11.y - bounds.minY) * scale;

        final rect = Rect.fromLTRB(
          math.min(x0, x1), math.min(y0, y1),
          math.max(x0, x1), math.max(y0, y1),
        );
        if (rect.width <= 0 || rect.height <= 0) continue;

        // valeur au centre
        final vcLon = (lon0 + lon1) * 0.5;
        final vcLat = (lat0 + lat1) * 0.5;
        final v = grid.sampleBilinear(vcLon, vcLat);
        if (v.isNaN) continue;

        paint.color = colormap(v).withOpacity(opacity);
        canvas.drawRect(rect, paint);
      }
    }
  }

  /// calcule un "cadre local" autour de l'origine mercator, en coordonnées locales
  _LocalBounds _estimateLocalBounds() {
    // origin est géographique -> convertissons-le en local (x,y)
    final originLocal = mercator.toLocal(mercator.config.origin);
    const span = 10_000.0; // 10 km (à ajuster selon ton usage/zoom)
    return _LocalBounds(
      originLocal.x - span, originLocal.x + span,
      originLocal.y - span, originLocal.y + span,
    );
  }

  @override
  bool shouldRepaint(covariant GribRasterPainter old) {
    return old.grid != grid ||
        old.opacity != opacity ||
        old.mercator.config.origin != mercator.config.origin ||
        old.samplingStride != samplingStride ||
        old.colormap != colormap;
  }
}

class _LocalBounds {
  final double minX, maxX, minY, maxY;
  const _LocalBounds(this.minX, this.maxX, this.minY, this.maxY);
}
