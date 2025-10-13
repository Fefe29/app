import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../features/charts/providers/mercator_coordinate_system_provider.dart';
import '../../../features/charts/domain/models/geographic_position.dart';
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

class GribRasterPainter extends CustomPainter {
  final ScalarGrid grid;
  final MercatorCoordinateSystemService mercator;
  final double opacity;       // 0..1
  final ColorMap colormap;
  final int samplingStride;   // 1 = chaque cellule
  final dynamic localBoundsOverride; // objet avec minX,maxX,minY,maxY (duck-typed)
  final bool debugDrawCoverage;

  GribRasterPainter({
    required this.grid,
    required this.mercator,
    required this.opacity,
    required this.colormap,
    this.samplingStride = 2,
    this.localBoundsOverride,
    this.debugDrawCoverage = false,
  });

  static const double margin = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Définir le cadre local (identique au CoursePainter si fourni)
    final bounds = _resolveLocalBounds();

    // 2) Calcule mapping local -> écran
    final availW = size.width - 2 * margin;
    final availH = size.height - 2 * margin;
    final spanX = bounds.maxX - bounds.minX;
    final spanY = bounds.maxY - bounds.minY;
    final scale = math.min(availW / spanX, availH / spanY);
    final offsetX = (size.width - spanX * scale) / 2;
    final offsetY = (size.height - spanY * scale) / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    // 3) Gestion des GRIBs où la latitude décroît (dlat négatif)
    final dlon = grid.dlon;
    final dlat = grid.dlat;
    final lonIncreasing = dlon > 0;
    final latIncreasing = dlat > 0;

    for (int jy = 0; jy < grid.ny - 1; jy += samplingStride) {
      for (int ix = 0; ix < grid.nx - 1; ix += samplingStride) {
        // Cellule (lon/lat) en tenant compte du sens
        final lon0 = grid.lon0 + (lonIncreasing ? ix : -ix) * dlon;
        final lon1 = grid.lon0 + (lonIncreasing ? (ix + samplingStride) : -(ix + samplingStride)) * dlon;
        final lat0 = grid.lat0 + (latIncreasing ? jy : -jy) * dlat;
        final lat1 = grid.lat0 + (latIncreasing ? (jy + samplingStride) : -(jy + samplingStride)) * dlat;

        // 4 coins → local
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
        final lonC = (lon0 + lon1) * 0.5;
        final latC = (lat0 + lat1) * 0.5;
        final v = grid.sampleBilinear(lonC, latC);
        if (v.isNaN) continue;

        paint.color = colormap(v).withOpacity(opacity);
        canvas.drawRect(rect, paint);
      }
    }

    // 4) Debug : dessine le cadre de couverture pour vérifier l’alignement
    if (debugDrawCoverage) {
      final border = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final pMin = Offset(
        offsetX + (bounds.minX - bounds.minX) * scale,
        size.height - offsetY - (bounds.minY - bounds.minY) * scale,
      );
      final pMax = Offset(
        offsetX + (bounds.maxX - bounds.minX) * scale,
        size.height - offsetY - (bounds.maxY - bounds.minY) * scale,
      );
      final r = Rect.fromPoints(
        Offset(pMin.dx, pMax.dy),
        Offset(pMax.dx, pMin.dy),
      );
      canvas.drawRect(r, border);
    }
  }

  _LocalBounds _resolveLocalBounds() {
    if (localBoundsOverride != null) {
      return _LocalBounds(
        localBoundsOverride.minX,
        localBoundsOverride.maxX,
        localBoundsOverride.minY,
        localBoundsOverride.maxY,
      );
    }
    // Fallback : 10 km autour de l’origine projetée
    final originLocal = mercator.toLocal(mercator.config.origin);
    const span = 10_000.0;
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
        old.colormap != colormap ||
        old.localBoundsOverride != localBoundsOverride ||
        old.debugDrawCoverage != debugDrawCoverage;
  }
}

class _LocalBounds {
  final double minX, maxX, minY, maxY;
  const _LocalBounds(this.minX, this.maxX, this.minY, this.maxY);
}
