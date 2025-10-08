/// Repository pour la gestion des cartes marines.
/// Interface d'accès aux données de cartes stockées localement.
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../models/map_tile_set.dart';
import '../models/map_bounds.dart';

/// Repository principal pour l'accès aux cartes
class MapRepository {
  MapRepository({required String storageDirectory}) 
      : _storageDir = storageDirectory;

  final String _storageDir;

  /// Récupère une tuile spécifique
  Future<Uint8List?> getTile(String mapId, int x, int y, int zoom) async {
    final tileFile = File(path.join(_storageDir, mapId, '${x}_${y}_${zoom}.png'));
    
    if (await tileFile.exists()) {
      return await tileFile.readAsBytes();
    }
    
    return null;
  }

  /// Vérifie si une tuile existe
  Future<bool> hasTile(String mapId, int x, int y, int zoom) async {
    final tileFile = File(path.join(_storageDir, mapId, '${x}_${y}_${zoom}.png'));
    return await tileFile.exists();
  }

  /// Récupère les métadonnées d'une carte
  Future<MapTileSet?> getMapMetadata(String mapId) async {
    final metadataFile = File(path.join(_storageDir, mapId, 'metadata.json'));
    
    if (await metadataFile.exists()) {
      // TODO: Implémenter la désérialisation JSON
      // Pour l'instant, retourne null
      return null;
    }
    
    return null;
  }

  /// Sauvegarde les métadonnées d'une carte
  Future<void> saveMapMetadata(MapTileSet mapTileSet) async {
    final mapDir = Directory(path.join(_storageDir, mapTileSet.id));
    await mapDir.create(recursive: true);
    
    final metadataFile = File(path.join(mapDir.path, 'metadata.json'));
    
    // TODO: Implémenter la sérialisation JSON
    // Pour l'instant, on créé juste le fichier
    await metadataFile.writeAsString('{}');
  }

  /// Liste toutes les cartes disponibles
  Future<List<String>> getAvailableMapIds() async {
    final maps = <String>[];
    final storageDir = Directory(_storageDir);
    
    if (await storageDir.exists()) {
      await for (final entity in storageDir.list()) {
        if (entity is Directory) {
          maps.add(path.basename(entity.path));
        }
      }
    }
    
    return maps;
  }

  /// Supprime une carte complètement
  Future<void> deleteMap(String mapId) async {
    final mapDir = Directory(path.join(_storageDir, mapId));
    if (await mapDir.exists()) {
      await mapDir.delete(recursive: true);
    }
  }

  /// Calcule l'espace de stockage utilisé par une carte
  Future<int> getMapStorageSize(String mapId) async {
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

  /// Calcule l'espace total utilisé par toutes les cartes
  Future<int> getTotalStorageSize() async {
    int totalSize = 0;
    final mapIds = await getAvailableMapIds();
    
    for (final mapId in mapIds) {
      totalSize += await getMapStorageSize(mapId);
    }
    
    return totalSize;
  }

  /// Nettoie les cartes anciennes ou corrompues
  Future<void> cleanupStorage() async {
    final mapIds = await getAvailableMapIds();
    
    for (final mapId in mapIds) {
      final mapDir = Directory(path.join(_storageDir, mapId));
      
      // Vérifier si le répertoire contient des fichiers
      bool hasValidFiles = false;
      await for (final entity in mapDir.list()) {
        if (entity is File && entity.path.endsWith('.png')) {
          hasValidFiles = true;
          break;
        }
      }
      
      // Supprimer les répertoires vides
      if (!hasValidFiles) {
        await mapDir.delete(recursive: true);
      }
    }
  }

  /// Vérifie l'intégrité d'une carte
  Future<bool> verifyMapIntegrity(String mapId) async {
    final mapDir = Directory(path.join(_storageDir, mapId));
    
    if (!await mapDir.exists()) {
      return false;
    }
    
    // Compter les tuiles présentes
    int tileCount = 0;
    await for (final entity in mapDir.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        tileCount++;
      }
    }
    
    // Une carte valide doit avoir au moins une tuile
    return tileCount > 0;
  }

  /// Trouve les cartes couvrant une zone géographique
  Future<List<String>> findMapsForBounds(MapBounds bounds) async {
    final matchingMaps = <String>[];
    final mapIds = await getAvailableMapIds();
    
    for (final mapId in mapIds) {
      final metadata = await getMapMetadata(mapId);
      if (metadata != null) {
        // Vérifier si les bounds se chevauchent
        if (_boundsOverlap(bounds, metadata.bounds)) {
          matchingMaps.add(mapId);
        }
      }
    }
    
    return matchingMaps;
  }

  /// Vérifie si deux zones géographiques se chevauchent
  bool _boundsOverlap(MapBounds bounds1, MapBounds bounds2) {
    return bounds1.minLatitude <= bounds2.maxLatitude &&
           bounds1.maxLatitude >= bounds2.minLatitude &&
           bounds1.minLongitude <= bounds2.maxLongitude &&
           bounds1.maxLongitude >= bounds2.minLongitude;
  }
}