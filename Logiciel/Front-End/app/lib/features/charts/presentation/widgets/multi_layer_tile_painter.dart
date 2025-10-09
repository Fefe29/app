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

class MultiLayerTilePainter extends CustomPainter {
  MultiLayerTilePainter(
    this.tiles,
    this.mercatorService,
    this.constraints,
    this.courseState,
    this.config,
  );
  
  final List<LayeredTile> tiles;
  final MercatorCoordinateSystemService mercatorService;
  final BoxConstraints constraints;
  final CourseState courseState;
  final MapLayersConfig config;

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

    print('MULTI-LAYER DEBUG - Dessin de ${tiles.length} tuiles multi-couches');

    final spanX = _bounds.maxX - _bounds.minX;
    final spanY = _bounds.maxY - _bounds.minY;
    final availW = size.width - 48.0;
    final availH = size.height - 48.0;
    final scale = math.min(availW / spanX, availH / spanY);

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final boundsOffsetX = (_bounds.minX + _bounds.maxX) / 2;
    final boundsOffsetY = (_bounds.minY + _bounds.maxY) / 2;

    // Organiser les tuiles pour respecter la grille OSM
    // Calculer la taille réelle d'une tuile en mètres (basé sur le zoom)
    final zoom = tiles.isNotEmpty ? tiles.first.zoom : 15;
    final realTileSize = _calculateMercatorTileSize(zoom);
    final screenTileSize = realTileSize * scale;

    // Dessiner chaque tuile avec projection Mercator unifiée
    for (final tile in tiles) {
      // Utiliser la conversion Mercator directe pour les coins de la tuile
      final localNW = mercatorService.tileToLocal(tile.x, tile.y, tile.zoom);
      final localSE = mercatorService.tileToLocal(tile.x + 1, tile.y + 1, tile.zoom);
      
      // Calculer les positions écran des coins avec la projection Mercator
      final screenNWx = centerX + (localNW.x - boundsOffsetX) * scale;
      final screenNWy = centerY - (localNW.y - boundsOffsetY) * scale;
      final screenSEx = centerX + (localSE.x - boundsOffsetX) * scale;
      final screenSEy = centerY - (localSE.y - boundsOffsetY) * scale;
      
      // Créer le rectangle correctement orienté (left < right, top < bottom)
      final rect = Rect.fromLTRB(
        math.min(screenNWx, screenSEx),   // left
        math.min(screenNWy, screenSEy),   // top 
        math.max(screenNWx, screenSEx),   // right
        math.max(screenNWy, screenSEy),   // bottom
      );

      print('MERCATOR DEBUG - Tuile ${tile.x},${tile.y}: NW local(${localNW.x.toStringAsFixed(1)},${localNW.y.toStringAsFixed(1)}) -> écran(${screenNWx.toStringAsFixed(1)},${screenNWy.toStringAsFixed(1)})');
      print('MERCATOR DEBUG - Tuile ${tile.x},${tile.y}: SE local(${localSE.x.toStringAsFixed(1)},${localSE.y.toStringAsFixed(1)}) -> écran(${screenSEx.toStringAsFixed(1)},${screenSEy.toStringAsFixed(1)})');
      print('MERCATOR DEBUG - Tuile ${tile.x},${tile.y}: Rect=${rect}, taille écran=${size.width}x${size.height}');
      print('MERCATOR DEBUG - Tuile ${tile.x},${tile.y}: baseImage=${tile.baseImage != null ? '${tile.baseImage!.width}x${tile.baseImage!.height}' : 'null'}');

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
        
        print('MERCATOR DEBUG - Tuile ${tile.x},${tile.y}: Couche base OSM dessinée avec opacité ${config.baseLayer.opacity}');
      } else {
        print('MERCATOR DEBUG - Tuile ${tile.x},${tile.y}: Couche base IGNORÉE (enabled=${config.baseLayer.enabled}, image=${tile.baseImage != null})');
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