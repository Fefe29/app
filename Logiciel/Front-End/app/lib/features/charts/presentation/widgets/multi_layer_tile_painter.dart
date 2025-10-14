/// Painter pour dessiner les tuiles multi-couches (OSM + OpenSeaMap)
import 'dart:math' as math;
import 'dart:ui' as ui;
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

      final rect = Rect.fromPoints(topLeft, bottomRight);

      // 4) Dessin des couches
      // Base raster (OSM)
      if (config.baseLayer.enabled && tile.baseImage != null) {
        final paint = Paint()
          ..color = Colors.white.withOpacity(config.baseLayer.opacity)
          ..filterQuality = FilterQuality.high;
        canvas.drawImageRect(
          tile.baseImage!,
          _fullImageRect(tile.baseImage),
          rect,
          paint,
        );
      }

      // Nautique (OpenSeaMap) au-dessus
      if (config.nauticalLayer.enabled && tile.nauticalImage != null) {
        final paint = Paint()
          ..color = Colors.white.withOpacity(config.nauticalLayer.opacity)
          ..filterQuality = FilterQuality.high
          ..blendMode = BlendMode.srcOver;
        canvas.drawImageRect(
          tile.nauticalImage!,
          _fullImageRect(tile.nauticalImage),
          rect,
          paint,
        );
      }

      // // Debug optionnel : cadre des tuiles
      // final dbg = Paint()
      //   ..style = PaintingStyle.stroke
      //   ..color = Colors.white24
      //   ..strokeWidth = 1;
      // canvas.drawRect(rect, dbg);
    }
  }

  Rect _fullImageRect(ui.Image? img) {
    if (img == null) return Rect.zero;
    return Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
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
