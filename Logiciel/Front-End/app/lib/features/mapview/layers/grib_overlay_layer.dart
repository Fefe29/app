import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/datasources/gribs/grib_overlay_models.dart';
import '../../../../data/datasources/gribs/grib_overlay_providers.dart';
import '../../charts/providers/mercator_coordinate_system_provider.dart';


class GribOverlayLayer extends ConsumerWidget {
  const GribOverlayLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = ref.watch(currentGribGridProvider);
    if (grid == null) return const SizedBox.shrink();

    final opacity = ref.watch(gribOpacityProvider).clamp(0.0, 1.0);
    final vmin = ref.watch(gribVminProvider);
    final vmax = ref.watch(gribVmaxProvider);
    final mercator = ref.watch(mercatorCoordinateSystemProvider);

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          painter: _GribScalarPainter(
            grid: grid,
            vmin: vmin,
            vmax: vmax,
            mercator: mercator,
            stride: 2, // échantillonnage léger
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _GribScalarPainter extends CustomPainter {
  _GribScalarPainter({
    required this.grid,
    required this.vmin,
    required this.vmax,
    required this.mercator,
    required this.stride,
  });

  final ScalarGrid grid;
  final double vmin, vmax;
  final dynamic mercator; // MercatorCoordinateSystemService
  final int stride;

  @override
  void paint(Canvas canvas, Size size) {
    if (grid.nx <= 0 || grid.ny <= 0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    // On dessine des petits rectangles colorés projetés (approx “heatmap”)
    for (int iy = 0; iy < grid.ny - 1; iy += stride) {
      for (int ix = 0; ix < grid.nx - 1; ix += stride) {
        final lon = grid.lon0 + ix * grid.dlon;
        final lat = grid.lat0 + iy * grid.dlat;
        final lon2 = lon + grid.dlon * stride;
        final lat2 = lat + grid.dlat * stride;

        // Convertit en coordonnées locales (m) via ton service Mercator
        final pSW = mercator.toLocalFromLatLon(lat, lon);
        final pNE = mercator.toLocalFromLatLon(lat2, lon2);

        // Proj écran: mercator local → écran (reprend ton scaling course_canvas)
        // Ici on suppose un scaling simple: on étire la zone visible automatiquement
        // Pour rester compact, on trace en écran relatif: petit pavé
        final val = grid.valueAtIndex(ix, iy);
        if (val.isNaN) continue;

        final t = ((val - vmin) / (vmax - vmin)).clamp(0.0, 1.0);
        paint.color = Color.lerp(Colors.blue, Colors.red, t)!;

        // Sans info de viewport ici, on rend en pixels “locaux” (approximation)
        // ➜ Tu peux remplacer par la même projection écran que `MultiLayerTilePainter`
        final rect = Rect.fromLTWH(
          pSW.x * 0.02 + size.width / 2,            // facteur arbitraire pour visualiser rapidement
          size.height / 2 - pNE.y * 0.02,
          (pNE.x - pSW.x).abs() * 0.02,
          (pNE.y - pSW.y).abs() * 0.02,
        );
        if (rect.width > 0 && rect.height > 0) {
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GribScalarPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.vmin != vmin ||
        oldDelegate.vmax != vmax ||
        oldDelegate.mercator != mercator ||
        oldDelegate.stride != stride;
  }
}
