/// Providers pour la gestion des cartes marines.
/// Fournit l'accès au service de téléchargement et au repository de cartes.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../services/map_download_service.dart';
import '../models/map_tile_set.dart';
import '../models/map_bounds.dart';
import '../repositories/map_repository.dart';

import '../../../../features/charts/providers/course_providers.dart';

/// Provider pour le répertoire de stockage des cartes
final mapStorageDirectoryProvider = FutureProvider<String>((ref) async {
  // Utiliser un chemin local dans le projet
  const projectPath = '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories';
  final mapsDir = Directory('$projectPath/downloaded_maps');
  
  if (!await mapsDir.exists()) {
    await mapsDir.create(recursive: true);
  }
  
  return mapsDir.path;
});

/// Provider pour le service de téléchargement de cartes
final mapDownloadServiceProvider = FutureProvider<MapDownloadService>((ref) async {
  final storageDir = await ref.watch(mapStorageDirectoryProvider.future);
  return MapDownloadService(storageDirectory: storageDir);
});

/// Provider pour le repository de cartes
final mapRepositoryProvider = FutureProvider<MapRepository>((ref) async {
  final storageDir = await ref.watch(mapStorageDirectoryProvider.future);
  return MapRepository(storageDirectory: storageDir);
});

/// Notifier pour la gestion de l'état des cartes
class MapManagerNotifier extends Notifier<List<MapTileSet>> {
  @override
  List<MapTileSet> build() {
    _loadMaps();
    return [];
  }

  /// Charge les cartes disponibles
  Future<void> _loadMaps() async {
    try {
      final downloadService = await ref.read(mapDownloadServiceProvider.future);
      final maps = await downloadService.getDownloadedMaps();
      state = maps;
    } catch (e) {
      print('Erreur lors du chargement des cartes: $e');
    }
  }

  /// Démarre le téléchargement d'une nouvelle carte
  Future<void> downloadMap(MapDownloadConfig config) async {
    try {
      final downloadService = await ref.read(mapDownloadServiceProvider.future);
      
      // Ajouter une carte en cours de téléchargement
      final downloadingMap = MapTileSet(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        name: config.name,
        bounds: config.bounds,
        zoomLevel: config.zoomLevel,
        status: MapDownloadStatus.downloading,
        description: config.description,
        downloadProgress: 0.0,
      );
      
      state = [...state, downloadingMap];
      
      // Démarrer le téléchargement
      await downloadService.downloadMap(config);
      
      // Recharger la liste des cartes
      await _loadMaps();
      
    } catch (e) {
      print('Erreur lors du téléchargement: $e');
      // Retirer la carte en erreur
      state = state.where((map) => map.status != MapDownloadStatus.downloading).toList();
    }
  }

  /// Supprime une carte
  Future<void> deleteMap(String mapId) async {
    try {
      final downloadService = await ref.read(mapDownloadServiceProvider.future);
      await downloadService.deleteMap(mapId);
      
      // Mettre à jour l'état
      state = state.where((map) => map.id != mapId).toList();
    } catch (e) {
      print('Erreur lors de la suppression: $e');
    }
  }

  /// Calcule les bounds optimaux pour le parcours actuel
  MapBounds? calculateCourseBounds() {
    final course = ref.read(courseProvider);
    
    if (course.buoys.isEmpty) return null;
    
    final positions = course.buoys.map((buoy) => buoy.position).toList();
    
    // Ajouter les lignes de départ/arrivée si elles existent
    if (course.startLine != null) {
      positions.add(course.startLine!.point1);
      positions.add(course.startLine!.point2);
    }
    
    if (course.finishLine != null) {
      positions.add(course.finishLine!.point1);
      positions.add(course.finishLine!.point2);
    }
    
    if (positions.isEmpty) return null;
    
    // Calculer les bounds avec une marge
    final baseBounds = MapBounds.fromPositions(positions);
    return baseBounds.expandBy(0.01); // Marge de 0.01° (~1km)
  }

  /// Crée une configuration de téléchargement pour le parcours actuel
  MapDownloadConfig? createCourseMapConfig({
    String? customName,
    int zoomLevel = 15,
  }) {
    final bounds = calculateCourseBounds();
    if (bounds == null) return null;
    
    final courseName = customName ?? 'Carte Parcours ${DateTime.now().day}/${DateTime.now().month}';
    
    return MapDownloadConfig(
      bounds: bounds,
      zoomLevel: zoomLevel,
      name: courseName,
      description: 'Carte générée automatiquement pour le parcours actuel',
    );
  }
}

/// Provider pour le gestionnaire de cartes
final mapManagerProvider = NotifierProvider<MapManagerNotifier, List<MapTileSet>>(
  MapManagerNotifier.new,
);

/// Provider pour les bounds du parcours actuel
final courseBoundsProvider = Provider<MapBounds?>((ref) {
  final mapManager = ref.watch(mapManagerProvider.notifier);
  return mapManager.calculateCourseBounds();
});

/// Provider pour vérifier si une carte couvre le parcours actuel
final mapCoversCourseProvider = Provider.family<bool, String>((ref, mapId) {
  final courseBounds = ref.watch(courseBoundsProvider);
  final maps = ref.watch(mapManagerProvider);
  
  if (courseBounds == null) return false;
  
  final map = maps.firstWhere(
    (m) => m.id == mapId,
    orElse: () => throw StateError('Carte non trouvée'),
  );
  
  // Vérifier si la carte couvre complètement le parcours
  return courseBounds.minLatitude >= map.bounds.minLatitude &&
         courseBounds.maxLatitude <= map.bounds.maxLatitude &&
         courseBounds.minLongitude >= map.bounds.minLongitude &&
         courseBounds.maxLongitude <= map.bounds.maxLongitude;
});