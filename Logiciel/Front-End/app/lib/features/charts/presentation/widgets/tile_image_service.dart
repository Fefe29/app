/// Service pour charger et gérer les tuiles de cartes téléchargées
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

class TileImageService {
  static final Map<String, ui.Image> _imageCache = {};
  
  /// Charge une tuile d'image depuis le fichier
  static Future<ui.Image?> loadTileImage(File tileFile) async {
    final key = tileFile.path;
    
    if (_imageCache.containsKey(key)) {
      return _imageCache[key];
    }
    
    try {
      if (!await tileFile.exists()) {
        return null;
      }
      
      final bytes = await tileFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      _imageCache[key] = frame.image;
      return frame.image;
    } catch (e) {
      print('Erreur chargement tuile ${tileFile.path}: $e');
      return null;
    }
  }
  
  /// Précharge toutes les tuiles d'une carte
  static Future<List<LoadedTile>> preloadMapTiles(String mapId, String mapPath) async {
    final tiles = <LoadedTile>[];
    final mapDir = Directory('$mapPath/$mapId');
    
    if (!await mapDir.exists()) {
      return tiles;
    }
    
    await for (final entity in mapDir.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        final filename = entity.path.split('/').last;
        final parts = filename.replaceAll('.png', '').split('_');
        
        if (parts.length == 3) {
          final x = int.tryParse(parts[0]);
          final y = int.tryParse(parts[1]);
          final zoom = int.tryParse(parts[2]);
          
          if (x != null && y != null && zoom != null) {
            final image = await loadTileImage(entity);
            if (image != null) {
              tiles.add(LoadedTile(
                x: x,
                y: y,
                zoom: zoom,
                image: image,
                file: entity,
              ));
            }
          }
        }
      }
    }
    
    return tiles;
  }
  
  /// Vide le cache d'images
  static void clearCache() {
    _imageCache.clear();
  }
}

class LoadedTile {
  const LoadedTile({
    required this.x,
    required this.y,
    required this.zoom,
    required this.image,
    required this.file,
  });
  
  final int x;
  final int y;
  final int zoom;
  final ui.Image image;
  final File file;
}

/// Provider pour les tuiles chargées
// Ce provider attend maintenant le chemin du dossier de stockage (à fournir dynamiquement)
final loadedTilesProvider = FutureProvider.family<List<LoadedTile>, MapTilesProviderParams>((ref, params) async {
  return await TileImageService.preloadMapTiles(params.mapId, params.mapPath);
});

class MapTilesProviderParams {
  final String mapId;
  final String mapPath;
  MapTilesProviderParams({required this.mapId, required this.mapPath});
}