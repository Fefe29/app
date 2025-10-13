// lib/features/charts/presentation/widgets/multi_layer_tile_painter.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../domain/models/geographic_position.dart';
import '../../providers/coordinate_system_provider.dart';
import '../../providers/mercator_coordinate_system_provider.dart';

import '../../../../data/datasources/maps/services/multi_layer_tile_service.dart';
import '../../../../data/datasources/maps/models/map_layer.dart';
import '../../domain/models/course.dart';

import 'viewport_bounds.dart';

class MultiLayerTilePainter extends CustomPainter {
  MultiLayerTilePainter(
    this.tiles,
    this.mercatorService,
    this.constraints,
    this.courseState,
    this.config, {
    this.externalBounds,
  });

  final List<LayeredTile> tiles;
  final MercatorCoordinateSystemService mercatorService;
  final BoxConstraints constraints;
  final CourseState courseState;
  final MapLayersConfig config;
  final ViewportBounds? externalBounds;

  // Calculer les bounds exactement comme dans _CoursePainter ou utiliser ceux fournis
  late final _Bounds _bounds = _computeBounds();

  _Bounds _computeBounds() {
    // ✅ Utilise les bounds externes s'ils sont fournis
    if (externalBounds != null) {
      return _Bounds(
        minX: externalBounds!.minX,
        maxX: externalBounds!.maxX,
        minY: externalBounds!.minY,
        maxY: externalBounds!.maxY,
      );
    }

    // Bounds par défaut si pas de parcours
    if (courseState.buoys.isEmpty && courseState.startLine == null && courseState.finishLine == null) {
      return _Bounds(minX: -500, maxX: 500, minY: -500, maxY: 500);
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    // Bounds des bouées avec projection Mercator
    for (final buoy in courseState.buoys) {
      final local = mercatorService.toLocal(buoy.position);
      minX = math.min(minX, local.x).toDouble();
      maxX = math.max(maxX, local.x).toDouble();
      minY = math.min(minY, local.y).toDouble();
      maxY = math.max(maxY, local.y).toDouble();
    }

    // Bounds des lignes avec projection Mercator
    for (final line in [courseState.startLine, courseState.finishLine]) {
      if (line != null) {
        final local1 = mercatorService.toLocal(line.point1);
        final local2 = mercatorService.toLocal(line.point2);
        minX = math.min(minX, math.min(local1.x, local2.x)).toDouble();
        maxX = math.max(maxX, math.max(local1.x, local2.x)).toDouble();
        minY = math.min(minY, math.min(local1.y, local2.y)).toDouble();
        maxY = math.max(maxY, math.max(local1.y, local2.y)).toDouble();
      }
    }

    // Inclure les bounds des tuiles
    for (final tile in tiles) {
      if (tile.baseImage != null) {
        // ✅ Récupère directement NW & SE en local
        final (nw, se) = mercatorService.tileBoundsLocal(tile.x, tile.y, tile.zoom);

        final left   = math.min(nw.x, se.x).toDouble();
        final right  = math.max(nw.x, se.x).toDouble();
        final bottom = math.min(nw.y, se.y).toDouble();
        final top    = math.max(nw.y, se.y).toDouble();

        minX = math.min(minX, left).toDouble();
        maxX = math.max(maxX, right).toDouble();
        minY = math.min(minY, bottom).toDouble();
        maxY = math.max(maxY, top).toDouble();
      }
    }

    const margin = 50.0;
    return _Bounds(
      minX: minX - margin,
      maxX: maxX + margin,
      minY: minY - margin,
      maxY: maxY + margin,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (tiles.isEmpty) return;

    // Garde-fou pour éviter divisions par zéro
    final spanXRaw = _bounds.maxX - _bounds.minX;
    final spanYRaw = _bounds.maxY - _bounds.minY;
    final spanX = spanXRaw.abs() < 1e-9 ? 1.0 : spanXRaw;
    final spanY = spanYRaw.abs() < 1e-9 ? 1.0 : spanYRaw;

    // Même logique que le canvas principal (marges proches)
    final availW = size.width - 48.0;
    final availH = size.height - 48.0;
    final scale = math.min(availW / spanX, availH / spanY);

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final boundsOffsetX = (_bounds.minX + _bounds.maxX) / 2;
    final boundsOffsetY = (_bounds.minY + _bounds.maxY) / 2;

    // Dessiner chaque tuile (OSM puis OpenSeaMap)
    for (final tile in tiles) {
      // ✅ Utilise maintenant tileBoundsLocal
      final (localNW, localSE) = mercatorService.tileBoundsLocal(tile.x, tile.y, tile.zoom);

      final screenNWx = centerX + (localNW.x - boundsOffsetX) * scale;
      final screenNWy = centerY - (localNW.y - boundsOffsetY) * scale;
      final screenSEx = centerX + (localSE.x - boundsOffsetX) * scale;
      final screenSEy = centerY - (localSE.y - boundsOffsetY) * scale;

      final rect = Rect.fromLTRB(
        math.min(screenNWx, screenSEx),
        math.min(screenNWy, screenSEy),
        math.max(screenNWx, screenSEx),
        math.max(screenNWy, screenSEy),
      );

      // Base OSM
      if (config.baseLayer.enabled && tile.baseImage != null) {
        final paint = Paint()
          ..color = Colors.white.withOpacity(config.baseLayer.opacity)
          ..filterQuality = FilterQuality.high;
        canvas.drawImageRect(
          tile.baseImage!,
          Rect.fromLTWH(0, 0, tile.baseImage!.width.toDouble(), tile.baseImage!.height.toDouble()),
          rect,
          paint,
        );
      }

      // Nautical overlay
      if (config.nauticalLayer.enabled && tile.nauticalImage != null) {
        final paint = Paint()
          ..color = Colors.white.withOpacity(config.nauticalLayer.opacity)
          ..filterQuality = FilterQuality.high
          ..blendMode = BlendMode.srcOver;
        canvas.drawImageRect(
          tile.nauticalImage!,
          Rect.fromLTWH(0, 0, tile.nauticalImage!.width.toDouble(), tile.nauticalImage!.height.toDouble()),
          rect,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant MultiLayerTilePainter old) {
    return old.tiles.length != tiles.length ||
        old.mercatorService.config.origin != mercatorService.config.origin ||
        old.config != config ||
        old.externalBounds?.minX != externalBounds?.minX ||
        old.externalBounds?.maxX != externalBounds?.maxX ||
        old.externalBounds?.minY != externalBounds?.minY ||
        old.externalBounds?.maxY != externalBounds?.maxY;
  }
}

class _Bounds {
  _Bounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}
