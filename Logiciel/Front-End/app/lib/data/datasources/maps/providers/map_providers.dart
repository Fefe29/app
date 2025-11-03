/// Providers pour la gestion des cartes marines.
/// Fournit l'accès au service de téléchargement et au repository de cartes.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/kornog_data_directory.dart';

import '../services/map_download_service.dart';
import '../models/map_tile_set.dart';
import '../models/map_bounds.dart';
import '../repositories/map_repository.dart';

import '../../../../features/charts/providers/course_providers.dart';

/// Provider pour le répertoire de stockage des cartes
final mapStorageDirectoryProvider = FutureProvider<String>((ref) async {
  print('[KORNOG_PROVIDER] mapStorageDirectoryProvider: début');
  print('[KORNOG_PROVIDER] Appel getKornogDataDirectory');
  final dir = await getKornogDataDirectory();
  print('[KORNOG_PROVIDER] getKornogDataDirectory OK: ${dir.path}');
  return dir.path;
});

/// Provider pour le service de téléchargement de cartes
final mapDownloadServiceProvider = FutureProvider<MapDownloadService>((ref) async {
  print('[KORNOG_PROVIDER] mapDownloadServiceProvider: attente storageDir');
  final storageDir = await ref.watch(mapStorageDirectoryProvider.future);
  print('[KORNOG_PROVIDER] mapDownloadServiceProvider: storageDir=$storageDir');
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
    print('[KORNOG_PROVIDER] downloadMap appelé');
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
      print('[KORNOG_PROVIDER] Erreur lors du téléchargement: $e');
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

/// Notifier pour la carte sélectionnée
class SelectedMapNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? mapId) {
    state = mapId;
  }
}

/// Notifier pour l'affichage des cartes
class MapDisplayNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle(bool show) {
    state = show;
  }
}

/// Provider pour la carte actuellement sélectionnée
final selectedMapProvider = NotifierProvider<SelectedMapNotifier, String?>(
  SelectedMapNotifier.new,
);

/// Provider pour l'affichage des cartes (activé/désactivé)
final mapDisplayProvider = NotifierProvider<MapDisplayNotifier, bool>(
  MapDisplayNotifier.new,
);

/// Provider pour la carte active à afficher
final activeMapProvider = Provider<MapTileSet?>((ref) {
  final selectedMapId = ref.watch(selectedMapProvider);
  final maps = ref.watch(mapManagerProvider);
  final displayMaps = ref.watch(mapDisplayProvider);
  
  if (!displayMaps || selectedMapId == null) return null;
  
  try {
    return maps.firstWhere(
      (map) => map.id == selectedMapId && map.status == MapDownloadStatus.completed,
    );
  } catch (e) {
    // Si la carte sélectionnée n'est pas trouvée, sélectionner automatiquement la première disponible
    final availableMaps = maps.where((map) => map.status == MapDownloadStatus.completed);
    if (availableMaps.isNotEmpty) {
      // Mise à jour asynchrone de la sélection
      Future.microtask(() {
        ref.read(selectedMapProvider.notifier).select(availableMaps.first.id);
      });
      return availableMaps.first;
    }
  }
  
  return null;
});