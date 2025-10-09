/// Painter pour dessiner les tuiles multi-couches (OSM + OpenSeaMap)
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../domain/models/geographic_position.dart';
import '../../providers/coordinate_system_provider.dart';
import '../../../../data/datasources/maps/services/multi_layer_tile_service.dart';
import '../../../../data/datasources/maps/models/map_layers.dart';
import '../../domain/models/course.dart';

class MultiLayerTilePainter extends CustomPainter {
  MultiLayerTilePainter(
    this.tiles,
    this.coordinateService,
    this.constraints,
    this.courseState,
    this.config,
  );
  
  final List<LayeredTile> tiles;
  final CoordinateSystemService coordinateService;
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

    // Bounds des bouées
    for (final buoy in courseState.buoys) {
      final local = coordinateService.toLocal(buoy.position);
      minX = math.min(minX, local.x);
      maxX = math.max(maxX, local.x);
      minY = math.min(minY, local.y);
      maxY = math.max(maxY, local.y);
    }

    // Bounds des lignes
    for (final line in [courseState.startLine, courseState.finishLine]) {
      if (line != null) {
        final local1 = coordinateService.toLocal(line.point1);
        final local2 = coordinateService.toLocal(line.point2);
        
        minX = math.min(minX, math.min(local1.x, local2.x));
        maxX = math.max(maxX, math.max(local1.x, local2.x));
        minY = math.min(minY, math.min(local1.y, local2.y));
        maxY = math.max(maxY, math.max(local1.y, local2.y));
      }
    }

    // Inclure les bounds des tuiles disponibles
    for (final tile in tiles) {
      if (tile.baseImage != null) {
        final geoPos = _tileToGeoPosition(tile.x, tile.y, tile.zoom);
        final local = coordinateService.toLocal(geoPos);
        
        // Taille approximative d'une tuile en mètres
        final realTileSize = _calculateRealTileSize(tile.zoom);
        
        minX = math.min(minX, local.x - realTileSize / 2);
        maxX = math.max(maxX, local.x + realTileSize / 2);
        minY = math.min(minY, local.y - realTileSize / 2);
        maxY = math.max(maxY, local.y + realTileSize / 2);
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
    final realTileSize = _calculateRealTileSize(zoom);
    final screenTileSize = realTileSize * scale;

    // Dessiner chaque tuile avec ses couches en respectant la grille OSM
    for (final tile in tiles) {
      // Calculer les 4 coins de la tuile en coordonnées géographiques
      final nw = _tileToGeoPosition(tile.x, tile.y, tile.zoom);           // Nord-Ouest
      final se = _tileToGeoPosition(tile.x + 1, tile.y + 1, tile.zoom);   // Sud-Est
      
      // Convertir en coordonnées locales
      final localNW = coordinateService.toLocal(nw);
      final localSE = coordinateService.toLocal(se);
      
      // Calculer les positions écran des coins
      // IMPORTANT: Inverser l'axe Y pour que les latitudes plus élevées soient en haut
      final screenNWx = centerX + (localNW.x - boundsOffsetX) * scale;
      final screenNWy = centerY - (localNW.y - boundsOffsetY) * scale;  // Inversé avec -
      final screenSEx = centerX + (localSE.x - boundsOffsetX) * scale;
      final screenSEy = centerY - (localSE.y - boundsOffsetY) * scale;  // Inversé avec -
      
      // Créer le rectangle correctement orienté (left < right, top < bottom)
      final rect = Rect.fromLTRB(
        math.min(screenNWx, screenSEx),   // left
        math.min(screenNWy, screenSEy),   // top 
        math.max(screenNWx, screenSEx),   // right
        math.max(screenNWy, screenSEy),   // bottom
      );

      print('PAINTER DEBUG - Tuile ${tile.x},${tile.y}: NW(${nw.latitude.toStringAsFixed(4)},${nw.longitude.toStringAsFixed(4)}) -> écran(${screenNWx.toStringAsFixed(1)},${screenNWy.toStringAsFixed(1)})');
      print('PAINTER DEBUG - Tuile ${tile.x},${tile.y}: SE(${se.latitude.toStringAsFixed(4)},${se.longitude.toStringAsFixed(4)}) -> écran(${screenSEx.toStringAsFixed(1)},${screenSEy.toStringAsFixed(1)})');
      print('PAINTER DEBUG - Tuile ${tile.x},${tile.y}: Rect=${rect}, taille écran=${size.width}x${size.height}');
      print('PAINTER DEBUG - Tuile ${tile.x},${tile.y}: baseImage=${tile.baseImage != null ? '${tile.baseImage!.width}x${tile.baseImage!.height}' : 'null'}');

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
        
        print('PAINTER DEBUG - Tuile ${tile.x},${tile.y}: Couche base OSM dessinée avec opacité ${config.baseLayer.opacity}');
      } else {
        print('PAINTER DEBUG - Tuile ${tile.x},${tile.y}: Couche base IGNORÉE (enabled=${config.baseLayer.enabled}, image=${tile.baseImage != null})');
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

  /// Convertit les coordonnées de tuile en position géographique (coin nord-ouest)
  GeographicPosition _tileToGeoPosition(int tileX, int tileY, int zoom) {
    final n = 1 << zoom;
    final lon = tileX / n * 360.0 - 180.0;
    // Formule correcte pour la projection Mercator inverse
    final latRad = math.atan((math.exp(math.pi * (1 - 2 * tileY / n)) - math.exp(-math.pi * (1 - 2 * tileY / n))) / 2);
    final lat = latRad * 180.0 / math.pi;
    
    return GeographicPosition(latitude: lat, longitude: lon);
  }

  /// Calcule la taille réelle d'une tuile en mètres
  double _calculateRealTileSize(int zoom) {
    const earthCircumference = 40075000.0; // mètres
    return earthCircumference / (1 << zoom);
  }

  @override
  bool shouldRepaint(MultiLayerTilePainter oldDelegate) {
    return oldDelegate.tiles.length != tiles.length ||
        oldDelegate.coordinateService.config.origin != coordinateService.config.origin ||
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