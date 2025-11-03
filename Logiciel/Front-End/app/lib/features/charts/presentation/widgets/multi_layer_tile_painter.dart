/// Painter pour dessiner les tuiles multi-couches (OSM + OpenSeaMap)
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/models/geographic_position.dart';
import '../../providers/mercator_coordinate_system_provider.dart';
import '../../../../data/datasources/maps/services/multi_layer_tile_service.dart';
import '../../../../data/datasources/maps/models/map_layers.dart';

// ⚠️ Importe ViewTransform depuis l’endroit où tu l’as défini
// Si tu l’as laissée dans course_canvas.dart :
import 'course_canvas.dart'; // pour ViewTransform

class MultiLayerTilePainter extends CustomPainter {
  MultiLayerTilePainter(
    this.tiles,
    this.mercatorService,
    this.view,
    this.config,
  );

  final List<LayeredTile> tiles;
  final MercatorCoordinateSystemService mercatorService;
  final ViewTransform view;
  final MapLayersConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    if (tiles.isEmpty) return;

    // Limite le dessin à la taille du widget
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (final tile in tiles) {
      // 1) Coins géographiques slippy (OSM) : NW = (x,y), SE = (x+1, y+1)
      final (latNW, lonNW) = _tileXyToLatLon(tile.x, tile.y, tile.zoom);
      final (latSE, lonSE) = _tileXyToLatLon(tile.x + 1, tile.y + 1, tile.zoom);

      // 2) Conversion géo -> local (Mercator commun)
      final nwLocal = mercatorService.toLocal(
        GeographicPosition(latitude: latNW, longitude: lonNW),
      );
      final seLocal = mercatorService.toLocal(
        GeographicPosition(latitude: latSE, longitude: lonSE),
      );

      // 3) Projection écran via la même ViewTransform que le parcours
      final topLeft = view.project(nwLocal.x, nwLocal.y, size);     // NW
      final bottomRight = view.project(seLocal.x, seLocal.y, size); // SE

      // Calcul du rectangle d'affichage de la tuile (dans le widget)
      final rect = Rect.fromPoints(topLeft, bottomRight);
      final widgetRect = Rect.fromLTWH(0, 0, size.width, size.height);
      final visibleRect = rect.intersect(widgetRect);
      if (visibleRect.isEmpty) continue;

      // Calcul du sous-rectangle source à afficher (dans l'image tuile)
      // On suppose que l'image couvre rect, donc on prend la portion visible
      final src = _subImageRect(
        rect,
        visibleRect,
        tile.baseImage?.width.toDouble() ?? 256.0,
        tile.baseImage?.height.toDouble() ?? 256.0,
      );

      // 4) Dessin des couches
      // Base raster (OSM)
      if (config.baseLayer.enabled && tile.baseImage != null) {
        final paint = Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..filterQuality = FilterQuality.high
          // Filtre doux : laisse passer le vert et le rouge, réduit modérément le bleu
          ..colorFilter = const ColorFilter.matrix(<double>[
            0.85, 0.10, 0.05, 0, 0, // R
            0.10, 0.85, 0.05, 0, 0, // G
            0.10, 0.10, 0.80, 0, 0, // B
            0,    0,    0,    1, 0, // A
          ]);
        canvas.drawImageRect(
          tile.baseImage!,
          src,
          visibleRect,
          paint,
        );
      }

      // Nautique (OpenSeaMap) au-dessus
      if (config.nauticalLayer.enabled && tile.nauticalImage != null) {
        final paint = Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..filterQuality = FilterQuality.high
          ..blendMode = BlendMode.srcOver
          // Filtre doux : laisse passer le vert et le rouge, réduit modérément le bleu
          ..colorFilter = const ColorFilter.matrix(<double>[
            0.85, 0.10, 0.05, 0, 0, // R
            0.10, 0.85, 0.05, 0, 0, // G
            0.10, 0.10, 0.80, 0, 0, // B
            0,    0,    0,    1, 0, // A
          ]);
        canvas.drawImageRect(
          tile.nauticalImage!,
          src,
          visibleRect,
          paint,
        );
      }
      // // Debug optionnel : cadre des tuiles
      // final dbg = Paint()
      //   ..style = PaintingStyle.stroke
      //   ..color = Colors.white24
      //   ..strokeWidth = 1;
      // canvas.drawRect(visibleRect, dbg);
    }
    canvas.restore();
  }

  /// Calcule le sous-rectangle source à afficher dans l'image tuile
  /// [tileRect] = zone de la tuile sur le widget, [visibleRect] = portion visible dans le widget
  /// [imgW], [imgH] = taille de l'image tuile
  Rect _subImageRect(Rect tileRect, Rect visibleRect, double imgW, double imgH) {
    final left = ((visibleRect.left - tileRect.left) / tileRect.width).clamp(0.0, 1.0) * imgW;
    final top = ((visibleRect.top - tileRect.top) / tileRect.height).clamp(0.0, 1.0) * imgH;
    final right = ((visibleRect.right - tileRect.left) / tileRect.width).clamp(0.0, 1.0) * imgW;
    final bottom = ((visibleRect.bottom - tileRect.top) / tileRect.height).clamp(0.0, 1.0) * imgH;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Convertit indices de tuile (x,y,z) en lat/lon du coin **NW**.
  /// (x+1, y+1) donnera naturellement le coin **SE**.
  (double, double) _tileXyToLatLon(int x, int y, int z) {
  final n = 1 << z;
  final lon = x / n * 360.0 - 180.0;
  // Remplace math.sinh par une version compatible
  double sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
  final latRad = math.atan(sinh(math.pi * (1 - 2 * y / n)));
  final lat = latRad * 180.0 / math.pi;
  return (lat, lon);
  }

  @override
  bool shouldRepaint(MultiLayerTilePainter old) {
    return old.tiles != tiles ||
        old.config != config ||
        old.mercatorService.config.origin != mercatorService.config.origin ||
        old.view.minX != view.minX ||
        old.view.maxX != view.maxX ||
        old.view.minY != view.minY ||
        old.view.maxY != view.maxY ||
        old.view.scale != view.scale ||
        old.view.offsetX != view.offsetX ||
        old.view.offsetY != view.offsetY;
  }
}
