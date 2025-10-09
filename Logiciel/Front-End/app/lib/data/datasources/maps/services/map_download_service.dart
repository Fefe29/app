/// Service de téléchargement de cartes OpenSeaMap
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:path/path.dart' as path;
import '../models/map_tile_set.dart';
import '../models/map_bounds.dart';

/// Service principal pour le téléchargement et la gestion des cartes
class MapDownloadService {
  MapDownloadService({
    required String storageDirectory,
  }) : _storageDir = storageDirectory;

  final String _storageDir;
  final Map<String, StreamController<MapTileSet>> _downloadControllers = {};
  final http.Client _httpClient = http.Client();

  /// Stream pour suivre les mises à jour des téléchargements
  Stream<MapTileSet> watchDownload(String mapId) {
    _downloadControllers[mapId] ??= StreamController<MapTileSet>.broadcast();
    return _downloadControllers[mapId]!.stream;
  }

  /// Démarre le téléchargement d'une carte
  Future<void> downloadMap(MapDownloadConfig config) async {
    final mapId = _generateMapId(config);
    
    try {
      // Validation de la configuration
      final errors = config.validate();
      if (errors.isNotEmpty) {
        throw MapDownloadException('Configuration invalide: ${errors.join(', ')}');
      }

      // Création du répertoire de stockage
      await _ensureStorageDirectory();

      // Calcul des tuiles à télécharger
      final tiles = _calculateTiles(config.bounds, config.zoomLevel);
      
      // Initialisation de l'état de téléchargement
      final initialState = MapTileSet(
        id: mapId,
        name: config.name,
        bounds: config.bounds,
        zoomLevel: config.zoomLevel,
        status: MapDownloadStatus.downloading,
        description: config.description,
        tileCount: tiles.length,
        downloadProgress: 0.0,
      );

      _emitUpdate(mapId, initialState);

      // Téléchargement des tuiles
      await _downloadTiles(config, tiles, mapId);

      // Finalisation
      final completedState = initialState.copyWith(
        status: MapDownloadStatus.completed,
        downloadProgress: 1.0,
        downloadedAt: DateTime.now(),
        fileSizeBytes: await _calculateStorageSize(mapId),
      );

      _emitUpdate(mapId, completedState);
      
    } catch (e) {
      final errorState = MapTileSet(
        id: mapId,
        name: config.name,
        bounds: config.bounds,
        zoomLevel: config.zoomLevel,
        status: MapDownloadStatus.failed,
        errorMessage: e.toString(),
      );
      
      _emitUpdate(mapId, errorState);
      rethrow;
    }
  }

  /// Annule un téléchargement en cours
  Future<void> cancelDownload(String mapId) async {
    // Implémentation de l'annulation
    final controller = _downloadControllers[mapId];
    if (controller != null) {
      // On pourrait ajouter une logique d'annulation ici
    }
  }

  /// Liste les cartes téléchargées
  Future<List<MapTileSet>> getDownloadedMaps() async {
    final maps = <MapTileSet>[];
    
    try {
      await _ensureStorageDirectory();
      final storageDir = Directory(_storageDir);
      
      await for (final entity in storageDir.list()) {
        if (entity is Directory) {
          final mapInfo = await _loadMapInfo(entity.path);
          if (mapInfo != null) {
            maps.add(mapInfo);
          }
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des cartes: $e');
    }
    
    return maps;
  }

  /// Supprime une carte téléchargée
  Future<void> deleteMap(String mapId) async {
    final mapDir = Directory(path.join(_storageDir, mapId));
    if (await mapDir.exists()) {
      await mapDir.delete(recursive: true);
    }
  }

  /// Génère un ID unique pour une carte
  String _generateMapId(MapDownloadConfig config) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final bounds = config.bounds;
    return 'map_${timestamp}_${bounds.minLatitude.toStringAsFixed(3)}_${bounds.minLongitude.toStringAsFixed(3)}';
  }

  /// Calcule les tuiles nécessaires pour une zone et un zoom
  List<TileCoordinate> _calculateTiles(MapBounds bounds, int zoomLevel) {
    final tiles = <TileCoordinate>[];
    
    // Conversion des coordonnées géographiques en coordonnées de tuiles
    final minTileX = _lonToTileX(bounds.minLongitude, zoomLevel);
    final maxTileX = _lonToTileX(bounds.maxLongitude, zoomLevel);
    final minTileY = _latToTileY(bounds.maxLatitude, zoomLevel); // Y inversé
    final maxTileY = _latToTileY(bounds.minLatitude, zoomLevel);

    for (int x = minTileX; x <= maxTileX; x++) {
      for (int y = minTileY; y <= maxTileY; y++) {
        tiles.add(TileCoordinate(x: x, y: y, zoom: zoomLevel));
      }
    }

    return tiles;
  }

  /// Télécharge les tuiles
  Future<void> _downloadTiles(MapDownloadConfig config, List<TileCoordinate> tiles, String mapId) async {
    int completed = 0;
    final total = tiles.length;

    // Téléchargement séquentiel pour respecter les serveurs OSM
    for (final tile in tiles) {
      try {
        await _downloadSingleTile(config, tile, mapId);
        completed++;
        
        // Mise à jour du progrès
        final progress = completed / total;
        final updateState = MapTileSet(
          id: mapId,
          name: config.name,
          bounds: config.bounds,
          zoomLevel: config.zoomLevel,
          status: MapDownloadStatus.downloading,
          tileCount: total,
          downloadProgress: progress,
        );
        
        _emitUpdate(mapId, updateState);

        // Délai pour respecter les serveurs
        await Future.delayed(config.requestDelay);
        
      } catch (e) {
        print('Erreur téléchargement tuile $tile: $e');
        // Continue avec les autres tuiles
      }
    }
  }

  /// Télécharge une seule tuile
  Future<void> _downloadSingleTile(MapDownloadConfig config, TileCoordinate tile, String mapId) async {
    final url = '${config.tileServer}/${tile.zoom}/${tile.x}/${tile.y}.png';
    
    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await _saveTile(mapId, tile, response.bodyBytes);
    } else {
      throw Exception('Erreur HTTP ${response.statusCode} pour $url');
    }
  }

  /// Sauvegarde une tuile sur le disque
  Future<void> _saveTile(String mapId, TileCoordinate tile, Uint8List data) async {
    final mapDir = Directory(path.join(_storageDir, mapId));
    await mapDir.create(recursive: true);
    
    final tileFile = File(path.join(mapDir.path, '${tile.x}_${tile.y}_${tile.zoom}.png'));
    await tileFile.writeAsBytes(data);
  }

  /// Assure que le répertoire de stockage existe
  Future<void> _ensureStorageDirectory() async {
    final dir = Directory(_storageDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Calcule la taille de stockage d'une carte
  Future<int> _calculateStorageSize(String mapId) async {
    int totalSize = 0;
    final mapDir = Directory(path.join(_storageDir, mapId));
    
    if (await mapDir.exists()) {
      await for (final entity in mapDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
    }
    
    return totalSize;
  }

  /// Charge les informations d'une carte depuis le disque
  Future<MapTileSet?> _loadMapInfo(String mapPath) async {
    final mapId = path.basename(mapPath);
    final size = await _calculateStorageSize(mapId);
    
    return MapTileSet(
      id: mapId,
      name: mapId,
      bounds: const MapBounds(
        minLatitude: 43.5,
        maxLatitude: 43.6,
        minLongitude: 7.0,
        maxLongitude: 7.1,
      ),
      zoomLevel: 15,
      status: MapDownloadStatus.completed,
      fileSizeBytes: size,
      downloadedAt: DateTime.now(),
    );
  }

  /// Émet une mise à jour pour un téléchargement
  void _emitUpdate(String mapId, MapTileSet state) {
    final controller = _downloadControllers[mapId];
    if (controller != null && !controller.isClosed) {
      controller.add(state);
    }
  }

  /// Conversion longitude vers X de tuile
  int _lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  /// Conversion latitude vers Y de tuile
  int _latToTileY(double lat, int zoom) {
    final latRad = lat * (pi / 180.0);
    return ((1.0 - log(tan(latRad) + (1 / cos(latRad))) / pi) / 2.0 * (1 << zoom)).floor();
  }

  /// Dispose des ressources
  void dispose() {
    for (final controller in _downloadControllers.values) {
      controller.close();
    }
    _downloadControllers.clear();
    _httpClient.close();
  }
}

/// Coordonnées d'une tuile
class TileCoordinate {
  const TileCoordinate({required this.x, required this.y, required this.zoom});
  
  final int x;
  final int y;
  final int zoom;
  
  @override
  String toString() => 'Tile($x, $y, zoom:$zoom)';
}

/// Exception lors du téléchargement de cartes
class MapDownloadException implements Exception {
  const MapDownloadException(this.message);
  
  final String message;
  
  @override
  String toString() => 'MapDownloadException: $message';
}