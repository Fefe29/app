/// Painter pour dessiner les tuiles multi-couches (OSM + OpenSeaMap)
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../domain/models/geographic_position.dart';
import '../../providers/coordinate_system_provider.dart';
import '../../providers/mercator_coordinate_system_provider.dart';
import '../../../../data/datasources/maps/services/multi_layer_tile_service.dart';
import '../../../../data/datasources/maps/models/map_layers.dart';
import '../../domain/models/course.dart';

import '../../../charts/providers/zoom_provider.dart';
import 'course_canvas.dart';

class MultiLayerTilePainter extends CustomPainter {
  MultiLayerTilePainter(
    this.tiles,
    this.mercatorService,
    this.constraints,
    this.courseState,
    this.config,
    {this.userZoom = 1.0}
  );

  final List<LayeredTile> tiles;
  final MercatorCoordinateSystemService mercatorService;
  final BoxConstraints constraints;
  final CourseState courseState;
  final MapLayersConfig config;
  final double userZoom;

  // Calculer les bounds exactement comme dans _CoursePainter
  late final _Bounds _bounds = _computeBounds();

  _Bounds _computeBounds() {
    if (courseState.buoys.isEmpty && courseState.startLine == null && courseState.finishLine == null) {
      // Bounds par défaut si pas de parcours
      return _Bounds(
        minX: -500.0,
        maxX: 500.0,
        minY: -500.0,
        maxY: 500.0,
      );
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    // Bounds des bouées avec projection Mercator
    for (final buoy in courseState.buoys) {
      final local = mercatorService.toLocal(buoy.position);
      minX = math.min(minX, local.x);
      maxX = math.max(maxX, local.x);
      minY = math.min(minY, local.y);
      maxY = math.max(maxY, local.y);
    }

    // Bounds des lignes avec projection Mercator
    for (final line in [courseState.startLine, courseState.finishLine]) {
      if (line != null) {
        final local1 = mercatorService.toLocal(line.point1);
        final local2 = mercatorService.toLocal(line.point2);
        
        minX = math.min(minX, math.min(local1.x, local2.x));
        maxX = math.max(maxX, math.max(local1.x, local2.x));
        minY = math.min(minY, math.min(local1.y, local2.y));
        maxY = math.max(maxY, math.max(local1.y, local2.y));
      }
    }

    // Inclure les bounds des tuiles avec projection Mercator unifiée
    for (final tile in tiles) {
      if (tile.baseImage != null) {
        // Utiliser directement la conversion Mercator
        final local = mercatorService.tileToLocal(tile.x, tile.y, tile.zoom);
        
        // Taille d'une tuile en mètres selon Mercator
        final tileSize = _calculateMercatorTileSize(tile.zoom);
        
        minX = math.min(minX, local.x);
        maxX = math.max(maxX, local.x + tileSize);
        minY = math.min(minY, local.y - tileSize); // Mercator: Y décroît vers le sud
        maxY = math.max(maxY, local.y);
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

    // Utilise la transformation factorisée pour la projection
    final margin = 24.0;
    final bounds = _computeBounds();
    final transform = CanvasTransform(
      minX: bounds.minX,
      maxX: bounds.maxX,
      minY: bounds.minY,
      maxY: bounds.maxY,
      margin: margin,
      width: size.width,
      height: size.height,
      userZoom: userZoom,
    );

    for (final tile in tiles) {
      final localNW = mercatorService.tileToLocal(tile.x, tile.y, tile.zoom);
      final localSE = mercatorService.tileToLocal(tile.x + 1, tile.y + 1, tile.zoom);
      final screenNW = transform.project(localNW.x, localNW.y);
      final screenSE = transform.project(localSE.x, localSE.y);
      final rect = Rect.fromLTRB(
        math.min(screenNW.dx, screenSE.dx),
        math.min(screenNW.dy, screenSE.dy),
        math.max(screenNW.dx, screenSE.dx),
        math.max(screenNW.dy, screenSE.dy),
      );
      // Dessiner la couche de base (OSM)
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
      // Dessiner la couche nautique (OpenSeaMap) par-dessus
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

  /// Calcule la taille d'une tuile en mètres selon la projection Mercator
  double _calculateMercatorTileSize(int zoom) {
    // Dans la projection Mercator, une tuile fait 256x256 pixels
    // et la résolution dépend du niveau de zoom
    const earthCircumference = 2 * math.pi * 6378137.0; // Circonférence Mercator
    return earthCircumference / (256 * math.pow(2, zoom));
  }

  @override
  bool shouldRepaint(MultiLayerTilePainter oldDelegate) {
    return oldDelegate.tiles.length != tiles.length ||
        oldDelegate.mercatorService.config.origin != mercatorService.config.origin ||
        oldDelegate.config != config;
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