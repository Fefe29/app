/// Modèles pour les couches de cartes multiples (OSM + OpenSeaMap)
import 'map_tile_set.dart';

/// Type de couche de carte
enum MapLayerType {
  base,      // Couche de base (OSM)
  nautical,  // Couche nautique (OpenSeaMap)
}

/// Configuration d'une couche de carte
class MapLayer {
  const MapLayer({
    required this.type,
    required this.name,
    required this.tileServer,
    required this.enabled,
    this.opacity = 1.0,
    this.zIndex = 0,
  });

  final MapLayerType type;
  final String name;
  final String tileServer;
  final bool enabled;
  final double opacity;    // Transparence (0.0 = transparent, 1.0 = opaque)
  final int zIndex;        // Ordre d'affichage (plus élevé = au-dessus)

  MapLayer copyWith({
    MapLayerType? type,
    String? name,
    String? tileServer,
    bool? enabled,
    double? opacity,
    int? zIndex,
  }) {
    return MapLayer(
      type: type ?? this.type,
      name: name ?? this.name,
      tileServer: tileServer ?? this.tileServer,
      enabled: enabled ?? this.enabled,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }
}

/// Configuration des couches de carte avec OSM + OpenSeaMap
class MapLayersConfig {
  const MapLayersConfig({
    required this.baseLayer,
    required this.nauticalLayer,
  });

  final MapLayer baseLayer;
  final MapLayer nauticalLayer;

  /// Configuration par défaut avec OSM + OpenSeaMap
  static const MapLayersConfig defaultConfig = MapLayersConfig(
    baseLayer: MapLayer(
      type: MapLayerType.base,
      name: 'OpenStreetMap',
      tileServer: 'https://tile.openstreetmap.org',
      enabled: true,
      opacity: 1.0,
      zIndex: 0,
    ),
    nauticalLayer: MapLayer(
      type: MapLayerType.nautical,
      name: 'OpenSeaMap',
      tileServer: 'https://tiles.openseamap.org/seamark',
      enabled: true,
      opacity: 0.8,  // Légèrement transparent pour voir la base
      zIndex: 1,
    ),
  );

  MapLayersConfig copyWith({
    MapLayer? baseLayer,
    MapLayer? nauticalLayer,
  }) {
    return MapLayersConfig(
      baseLayer: baseLayer ?? this.baseLayer,
      nauticalLayer: nauticalLayer ?? this.nauticalLayer,
    );
  }

  /// Retourne toutes les couches activées triées par zIndex
  List<MapLayer> get enabledLayers {
    final layers = <MapLayer>[];
    if (baseLayer.enabled) layers.add(baseLayer);
    if (nauticalLayer.enabled) layers.add(nauticalLayer);
    
    layers.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return layers;
  }
}

/// Extension du MapTileSet pour supporter les couches multiples
extension MapTileSetLayers on MapTileSet {
  /// Génère une configuration de couches basée sur cette carte
  MapLayersConfig get layersConfig => MapLayersConfig.defaultConfig;
}