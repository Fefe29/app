/// Service pour gérer les tuiles multi-couches (OSM + OpenSeaMap)
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/map_tile_set.dart';
import '../models/map_layer.dart';

class LayeredTile {
  const LayeredTile({
    required this.x,
    required this.y,
    required this.zoom,
    required this.baseImage,
    this.nauticalImage,
  });

  final int x;
  final int y;
  final int zoom;
  final ui.Image? baseImage;    // Couche de base (OSM)
  final ui.Image? nauticalImage; // Couche nautique (OpenSeaMap)
}

class MultiLayerTileService {
  static final Map<String, ui.Image> _imageCache = {};
  static final http.Client _httpClient = http.Client();

  /// Charge une tuile avec ses multiples couches
  static Future<LayeredTile> loadLayeredTile({
    required int x,
    required int y,
    required int zoom,
    required MapLayersConfig config,
    String? localMapPath,
  }) async {
    ui.Image? baseImage;
    ui.Image? nauticalImage;

    // Charger la couche de base (locale si disponible, sinon en ligne)
    if (config.baseLayer.enabled) {
      if (localMapPath != null) {
        // Essayer de charger depuis les tuiles locales
        final localFile = File('$localMapPath/${x}_${y}_$zoom.png');
        baseImage = await _loadImageFromFile(localFile);
      }
      
      // Si pas de tuile locale, télécharger depuis OSM
      if (baseImage == null) {
        baseImage = await _downloadTileImage(
          config.baseLayer.tileServer,
          x, y, zoom,
        );
      }
    }

    // Charger la couche nautique depuis OpenSeaMap
    if (config.nauticalLayer.enabled) {
      nauticalImage = await _downloadTileImage(
        config.nauticalLayer.tileServer,
        x, y, zoom,
      );
    }

    return LayeredTile(
      x: x,
      y: y,
      zoom: zoom,
      baseImage: baseImage,
      nauticalImage: nauticalImage,
    );
  }

  /// Charge une image depuis un fichier local
  static Future<ui.Image?> _loadImageFromFile(File file) async {
    final key = file.path;
    
    if (_imageCache.containsKey(key)) {
      return _imageCache[key];
    }
    
    try {
      if (!await file.exists()) {
        return null;
      }
      
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      _imageCache[key] = frame.image;
      return frame.image;
    } catch (e) {
      print('Erreur lors du chargement de la tuile locale: $e');
      return null;
    }
  }

  /// Télécharge une tuile depuis un serveur distant
  static Future<ui.Image?> _downloadTileImage(
    String tileServer,
    int x, int y, int zoom,
  ) async {
    final url = '$tileServer/$zoom/$x/$y.png';
    final key = 'remote_$url';
    
    if (_imageCache.containsKey(key)) {
      return _imageCache[key];
    }
    
    try {
      final response = await _httpClient.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        
        _imageCache[key] = frame.image;
        return frame.image;
      }
    } catch (e) {
      print('Erreur lors du téléchargement de la tuile: $e');
    }
    
    return null;
  }

  /// Pré-charge les tuiles pour une zone donnée
  static Future<List<LayeredTile>> preloadLayeredTiles({
    required String mapId,
    required String mapPath,
    required MapLayersConfig config,
  }) async {
    print('MULTI-LAYER DEBUG - Chargement des tuiles avec couches multiples pour: $mapId');
    
    final tiles = <LayeredTile>[];
    final mapDir = Directory(mapPath);
    
    if (!await mapDir.exists()) {
      print('MULTI-LAYER DEBUG - Répertoire de cartes non trouvé: $mapPath');
      return tiles;
    }

    // Lister les fichiers de tuiles existants
    final files = await mapDir.list()
        .where((entity) => entity is File && entity.path.endsWith('.png'))
        .cast<File>()
        .toList();

    print('MULTI-LAYER DEBUG - ${files.length} tuiles trouvées');

    for (final file in files) {
      try {
        // Parser le nom du fichier: x_y_zoom.png
        final baseName = file.path.split('/').last.replaceAll('.png', '');
        final parts = baseName.split('_');
        if (parts.length != 3) continue;

        final x = int.parse(parts[0]);
        final y = int.parse(parts[1]);
        final zoom = int.parse(parts[2]);

        print('MULTI-LAYER DEBUG - Traitement tuile X:$x Y:$y Z:$zoom');

        // Charger la tuile avec ses couches
        final layeredTile = await loadLayeredTile(
          x: x,
          y: y,
          zoom: zoom,
          config: config,
          localMapPath: mapPath,
        );

        tiles.add(layeredTile);
      } catch (e) {
        print('MULTI-LAYER DEBUG - Erreur lors du chargement de ${file.path}: $e');
      }
    }

    // Trier les tuiles par Y puis X pour un rendu ordonné
    tiles.sort((a, b) {
      final yCompare = a.y.compareTo(b.y);
      return yCompare != 0 ? yCompare : a.x.compareTo(b.x);
    });

    print('MULTI-LAYER DEBUG - ${tiles.length} tuiles multi-couches chargées et triées');
    return tiles;
  }

  /// Nettoie le cache d'images
  static void clearCache() {
    _imageCache.clear();
  }
}