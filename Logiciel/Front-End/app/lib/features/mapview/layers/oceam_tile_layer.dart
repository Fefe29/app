/// Layer pour afficher les tuiles OSeaM en streaming
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

import '../../../../data/datasources/maps/services/oceam_tile_service.dart';
import '../../../../data/datasources/maps/providers/map_providers.dart';
import '../../charts/providers/mercator_coordinate_system_provider.dart';
import '../../charts/providers/course_providers.dart';
import '../../charts/presentation/models/view_transform.dart';
import '../../charts/domain/models/geographic_position.dart';

/// Représente une tuile OSeaM chargée
class OSeaMTile {
  OSeaMTile({
    required this.x,
    required this.y,
    required this.z,
    required this.imageData,
  });

  final int x;
  final int y;
  final int z;
  final Uint8List imageData;

  ui.Image? _cachedImage;
  Completer<ui.Image?>? _imageCompleter;

  Future<ui.Image?> get image {
    if (_cachedImage != null) {
      return Future.value(_cachedImage);
    }
    if (_imageCompleter != null) {
      return _imageCompleter!.future;
    }
    
    _imageCompleter = Completer<ui.Image?>();
    try {
      ui.decodeImageFromList(imageData, (image) {
        _cachedImage = image;
        _imageCompleter!.complete(image);
      });
    } catch (e) {
      print('[OSeaM] Erreur décodage image: $e');
      _imageCompleter!.complete(null);
    }
    return _imageCompleter!.future;
  }
}

/// Tuile OSeaM chargée avec image
class OSeaMLayeredTile {
  OSeaMLayeredTile({
    required this.x,
    required this.y,
    required this.z,
    required this.image,
  });

  final int x;
  final int y;
  final int z;
  final ui.Image image;
}

/// Provider pour charger les tuiles OSeaM visibles
final oceamVisibleTilesProvider = FutureProvider.family<List<OSeaMLayeredTile>, (MercatorCoordinateSystemService, dynamic, ViewTransform?)>((ref, params) async {
  print('[OSeaM] oceamVisibleTilesProvider called with params: ${params.$1.runtimeType}, courseState, ${params.$3?.runtimeType}');
  final (mercatorService, courseState, view) = params;
  final oceamService = ref.watch(oceamTileServiceProvider);
  
  final tiles = await _loadOSeaMTiles(
    oceamService,
    mercatorService,
    courseState,
    view,
  );
  print('[OSeaM] Provider loaded ${tiles.length} tiles');
  return tiles;
});

/// Charge les tuiles OSeaM visibles
Future<List<OSeaMLayeredTile>> _loadOSeaMTiles(
  OSeaMTileService service,
  MercatorCoordinateSystemService mercatorService,
  dynamic courseState,
  ViewTransform? view,
) async {
  print('[OSeaM] _loadOSeaMTiles called');
  // Zoom fixe pour OSeaM
  final zoom = 15;
  
  // Calculer les tuiles visibles
  final visibleTiles = _calculateVisibleTiles(courseState, zoom);
  print('[OSeaM] Visible tiles count: ${visibleTiles.length}');

  if (visibleTiles.isEmpty) {
    print('[OSeaM] No visible tiles');
    return [];
  }

  // Charger les tuiles
  final loadedTiles = <OSeaMLayeredTile>[];

  for (final (x, y, z) in visibleTiles) {
    try {
      print('[OSeaM] Fetching tile z=$z x=$x y=$y');
      final data = await service.getTile(x, y, z);
      if (data != null) {
        print('[OSeaM] Tile data received, decoding...');
        final completer = Completer<ui.Image?>();
        ui.decodeImageFromList(data, (image) {
          print('[OSeaM] Tile image decoded z=$z x=$x y=$y');
          completer.complete(image);
        });
        final image = await completer.future;
        if (image != null) {
          loadedTiles.add(OSeaMLayeredTile(
            x: x,
            y: y,
            z: z,
            image: image,
          ));
          print('[OSeaM] Tile added to loadedTiles, total: ${loadedTiles.length}');
        }
      } else {
        print('[OSeaM] Tile data null for z=$z x=$x y=$y');
      }
    } catch (e) {
      print('[OSeaM] Error loading tile $z/$x/$y: $e');
    }
  }

  print('[OSeaM] _loadOSeaMTiles finished, loaded ${loadedTiles.length} tiles');
  return loadedTiles;
}

/// Calcule les tuiles visibles pour le zoom courant
List<(int, int, int)> _calculateVisibleTiles(
  dynamic courseState,
  int zoom,
) {
  final tiles = <(int, int, int)>[];

  // Récupérer les bounds du parcours
  if (courseState.buoys.isEmpty) {
    // Par défaut: une grille 3x3 autour de l'origine
    final centerTile = _latLonToTile(0, 0, zoom);
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        tiles.add((centerTile.$1 + dx, centerTile.$2 + dy, zoom));
      }
    }
    return tiles;
  }

  // Calculer les tuiles couvrant le parcours
  final buoys = courseState.buoys;
  int minX = 0x7FFFFFFF, maxX = 0, minY = 0x7FFFFFFF, maxY = 0;

  for (final buoy in buoys) {
    final (x, y) = _latLonToTile(buoy.position.latitude, buoy.position.longitude, zoom);
    minX = minX > x ? x : minX;
    maxX = maxX < x ? x : maxX;
    minY = minY > y ? y : minY;
    maxY = maxY < y ? y : maxY;
  }

  // Ajouter une marge
  final n = 1 << zoom;
  minX = (minX - 1).clamp(0, n - 1);
  maxX = (maxX + 1).clamp(0, n - 1);
  minY = (minY - 1).clamp(0, n - 1);
  maxY = (maxY + 1).clamp(0, n - 1);

  // Générer la grille
  for (int x = minX; x <= maxX; x++) {
    for (int y = minY; y <= maxY; y++) {
      tiles.add((x, y, zoom));
    }
  }

  return tiles;
}

/// Convertit lat/lon en coordonnées de tuile
(int, int) _latLonToTile(double lat, double lon, int zoom) {
  final n = 1 << zoom;
  final x = ((lon + 180.0) / 360.0 * n).floor();
  
  final latRad = lat * math.pi / 180.0;
  final tanVal = math.tan(latRad);
  final cosVal = 1.0 / math.cos(latRad);
  
  final y = ((1.0 - (math.atan(tanVal + cosVal) / math.pi)) / 2.0 * n).floor();
  
  return (x.clamp(0, n - 1), y.clamp(0, n - 1));
}


/// Painter pour les tuiles OSeaM
class OSeaMTilePainter extends CustomPainter {
  OSeaMTilePainter(
    this.tiles,
    this.mercatorService,
    this.view,
  );

  final List<OSeaMLayeredTile> tiles;
  final MercatorCoordinateSystemService mercatorService;
  final ViewTransform? view;

  @override
  void paint(Canvas canvas, Size size) {
    if (tiles.isEmpty) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Dessiner chaque tuile avec conversion géographique
    for (final tile in tiles) {
      try {
        // Convertir x,y,z tuile → lat/lon
        final n = 1 << tile.z;
        final lonNW = tile.x / n * 360.0 - 180.0;
        final lonSE = (tile.x + 1) / n * 360.0 - 180.0;
        
        // Latitude avec Mercator inverse
        final latNW = _tileYToLat(tile.y, tile.z);
        final latSE = _tileYToLat(tile.y + 1, tile.z);

        // Convertir en coordonnées locales
        final nwLocal = mercatorService.toLocal(
          GeographicPosition(latitude: latNW, longitude: lonNW),
        );
        final seLocal = mercatorService.toLocal(
          GeographicPosition(latitude: latSE, longitude: lonSE),
        );

        // Pas de view transform fourni, utiliser les coordonnées brutes
        // C'est un positionnement simpliste pour démarrer
        final tileSize = 256.0;
        final screenX = (tile.x % 10) * tileSize;
        final screenY = (tile.y % 10) * tileSize;
        
        final rect = Rect.fromLTWH(screenX, screenY, tileSize, tileSize);
        final widgetRect = Rect.fromLTWH(0, 0, size.width, size.height);
        final visibleRect = rect.intersect(widgetRect);
        
        if (visibleRect.isEmpty) continue;

        final paint = Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true;

        canvas.drawImageRect(
          tile.image,
          Rect.fromLTWH(0, 0, tile.image.width.toDouble(), tile.image.height.toDouble()),
          rect,
          paint,
        );
      } catch (e) {
        print('[OSeaM] Erreur dessin tuile: $e');
      }
    }

    canvas.restore();
  }

  /// Convertit indice Y de tuile en latitude
  double _tileYToLat(int y, int z) {
    final n = 1 << z;
    // sinh(x) = (e^x - e^-x) / 2
    final sinhValue = _sinh(math.pi * (1 - 2 * y / n));
    final latRad = math.atan(sinhValue);
    return latRad * 180.0 / math.pi;
  }
  
  /// Calcule sinh(x) = (e^x - e^-x) / 2
  double _sinh(double x) {
    return (math.exp(x) - math.exp(-x)) / 2.0;
  }

  @override
  bool shouldRepaint(OSeaMTilePainter old) {
    return old.tiles.length != tiles.length ||
        old.tiles.asMap().entries.any((e) =>
            e.value.x != tiles[e.key].x ||
            e.value.y != tiles[e.key].y);
  }
}
