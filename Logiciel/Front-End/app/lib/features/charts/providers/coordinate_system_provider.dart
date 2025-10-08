/// Coordinate system management service for the sailing application.
/// Provides conversion between geographic and local coordinate systems.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/geographic_position.dart';

/// Configuration for the coordinate system
class CoordinateSystemConfig {
  const CoordinateSystemConfig({
    required this.origin,
    required this.name,
    this.description,
  });

  final GeographicPosition origin;
  final String name;
  final String? description;

  CoordinateSystemConfig copyWith({
    GeographicPosition? origin,
    String? name,
    String? description,
  }) => CoordinateSystemConfig(
        origin: origin ?? this.origin,
        name: name ?? this.name,
        description: description ?? this.description,
      );
}

/// Service managing coordinate system conversions
class CoordinateSystemService {
  CoordinateSystemService({
    required CoordinateSystemConfig config,
  }) : _config = config,
       _converter = CoordinateConverter(origin: config.origin);

  final CoordinateSystemConfig _config;
  final CoordinateConverter _converter;

  /// Current coordinate system configuration
  CoordinateSystemConfig get config => _config;

  /// Convert geographic position to local meters
  LocalPosition toLocal(GeographicPosition geo) => _converter.geographicToLocal(geo);

  /// Convert local meters to geographic position
  GeographicPosition toGeographic(LocalPosition local) => _converter.localToGeographic(local);

  /// Get distance between two geographic points in meters
  double distanceMeters(GeographicPosition pos1, GeographicPosition pos2) =>
      CoordinateConverter.distanceMeters(pos1, pos2);

  /// Get bearing from pos1 to pos2 in degrees
  double bearingDegrees(GeographicPosition pos1, GeographicPosition pos2) =>
      CoordinateConverter.bearingDegrees(pos1, pos2);

  /// Create a new service with different origin
  CoordinateSystemService withOrigin(GeographicPosition newOrigin, {String? name}) =>
      CoordinateSystemService(
        config: CoordinateSystemConfig(
          origin: newOrigin,
          name: name ?? '${newOrigin.latitude.toStringAsFixed(4)}, ${newOrigin.longitude.toStringAsFixed(4)}',
        ),
      );
}

/// Notifier for managing coordinate system configuration
class CoordinateSystemNotifier extends Notifier<CoordinateSystemService> {
  @override
  CoordinateSystemService build() {
    // Default to downloaded map area (43.535, 6.999)
    return CoordinateSystemService(
      config: const CoordinateSystemConfig(
        origin: GeographicPosition(latitude: 43.535, longitude: 6.999),
        name: 'Carte téléchargée',
        description: 'Zone des tuiles OpenStreetMap téléchargées',
      ),
    );
  }

  /// Update the coordinate system origin
  void setOrigin(GeographicPosition origin, {String? name, String? description}) {
    state = CoordinateSystemService(
      config: CoordinateSystemConfig(
        origin: origin,
        name: name ?? 'Personnalisé',
        description: description,
      ),
    );
  }

  /// Set to a preset coordinate system
  void setPreset(String presetName) {
    GeographicPosition origin;
    String name;
    String description;

    switch (presetName.toLowerCase()) {
      case 'mediterranean':
        origin = CoordinateSystemPresets.mediterranean;
        name = 'Méditerranée';
        description = 'Côte d\'Azur, France';
        break;
      case 'english_channel':
        origin = CoordinateSystemPresets.englishChannel;
        name = 'Manche';
        description = 'Portsmouth, Angleterre';
        break;
      case 'san_francisco':
        origin = CoordinateSystemPresets.sanFranciscoBay;
        name = 'San Francisco';
        description = 'Baie de San Francisco, USA';
        break;
      case 'sydney':
        origin = CoordinateSystemPresets.sydneyHarbour;
        name = 'Sydney';
        description = 'Port de Sydney, Australie';
        break;
      default:
        throw ArgumentError('Preset inconnu: $presetName');
    }

    state = CoordinateSystemService(
      config: CoordinateSystemConfig(
        origin: origin,
        name: name,
        description: description,
      ),
    );
  }

  /// Auto-detect best origin from current course data
  void autoDetectFromCourse(List<GeographicPosition> positions) {
    if (positions.isEmpty) return;

    // Calculate centroid of all positions
    double sumLat = 0;
    double sumLon = 0;
    for (final pos in positions) {
      sumLat += pos.latitude;
      sumLon += pos.longitude;
    }

    final centroid = GeographicPosition(
      latitude: sumLat / positions.length,
      longitude: sumLon / positions.length,
    );

    setOrigin(
      centroid,
      name: 'Auto-détecté',
      description: 'Centroïde du parcours',
    );
  }
}

/// Provider for the coordinate system service
final coordinateSystemProvider = NotifierProvider<CoordinateSystemNotifier, CoordinateSystemService>(() {
  return CoordinateSystemNotifier();
});

/// Convenience provider for quick access to coordinate conversion
final coordinateConverterProvider = Provider<CoordinateConverter>((ref) {
  final service = ref.watch(coordinateSystemProvider);
  return CoordinateConverter(origin: service.config.origin);
});