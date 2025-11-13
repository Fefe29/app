/// Service de système de coordonnées basé sur la projection Mercator
/// Remplace l'ancien système de projection plane pour une meilleure précision
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/geographic_position.dart';
import '../domain/services/mercator_projection.dart';

/// Configuration pour le système de coordonnées Mercator
class MercatorCoordinateSystemConfig {
  const MercatorCoordinateSystemConfig({
    required this.origin,
    required this.name,
    this.description,
  });

  final GeographicPosition origin;
  final String name;
  final String? description;

  MercatorCoordinateSystemConfig copyWith({
    GeographicPosition? origin,
    String? name,
    String? description,
  }) => MercatorCoordinateSystemConfig(
        origin: origin ?? this.origin,
        name: name ?? this.name,
        description: description ?? this.description,
      );
}

/// Service de gestion des coordonnées basé sur Mercator
class MercatorCoordinateSystemService {
  MercatorCoordinateSystemService({
    required MercatorCoordinateSystemConfig config,
  }) : _config = config,
       _projection = UnifiedCoordinateSystem(origin: config.origin);

  final MercatorCoordinateSystemConfig _config;
  final UnifiedCoordinateSystem _projection;

  /// Configuration actuelle du système de coordonnées
  MercatorCoordinateSystemConfig get config => _config;

  /// Convertit position géographique vers coordonnées locales en mètres
  LocalPosition toLocal(GeographicPosition geo) => _projection.geographicToLocal(geo);

  /// Convertit coordonnées locales vers position géographique
  GeographicPosition toGeographic(LocalPosition local) => _projection.localToGeographic(local);

  /// Convertit tuile OSM vers coordonnées locales
  LocalPosition tileToLocal(int tileX, int tileY, int zoom) => _projection.tileToLocal(tileX, tileY, zoom);

  /// Calcule la distance entre deux positions géographiques en mètres
  double distanceMeters(GeographicPosition pos1, GeographicPosition pos2) {
    final local1 = toLocal(pos1);
    final local2 = toLocal(pos2);
    final dx = local2.x - local1.x;
    final dy = local2.y - local1.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Calcule le bearing de pos1 vers pos2 en degrés (0 = Nord, 90 = Est)
  double bearingDegrees(GeographicPosition pos1, GeographicPosition pos2) {
    final local1 = toLocal(pos1);
    final local2 = toLocal(pos2);
    final dx = local2.x - local1.x;
    final dy = local2.y - local1.y;
    final bearingRad = math.atan2(dx, dy);
    return (bearingRad * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// Crée un nouveau service avec une origine différente
  MercatorCoordinateSystemService withOrigin(GeographicPosition newOrigin, {String? name}) =>
      MercatorCoordinateSystemService(
        config: MercatorCoordinateSystemConfig(
          origin: newOrigin,
          name: name ?? 'Mercator ${newOrigin.latitude.toStringAsFixed(4)}, ${newOrigin.longitude.toStringAsFixed(4)}',
        ),
      );
}

/// Notifier pour gérer la configuration du système de coordonnées Mercator
class MercatorCoordinateSystemNotifier extends Notifier<MercatorCoordinateSystemService> {
  @override
  MercatorCoordinateSystemService build() {
    // Utiliser Brest (Rade de Brest) comme origine par défaut
    return MercatorCoordinateSystemService(
      config: const MercatorCoordinateSystemConfig(
        origin: GeographicPosition(latitude: 48.38, longitude: -4.50),
        name: 'Mercator - Rade de Brest',
        description: 'Rade de Brest, Bretagne (Mercator)',
      ),
    );
  }

  /// Met à jour l'origine du système de coordonnées
  void setOrigin(GeographicPosition origin, {String? name, String? description}) {
    state = MercatorCoordinateSystemService(
      config: MercatorCoordinateSystemConfig(
        origin: origin,
        name: name ?? 'Mercator Personnalisé',
        description: description,
      ),
    );
  }

  /// Configure un système prédéfini
  void setPreset(String presetName) {
    GeographicPosition origin;
    String name;
    String description;

    switch (presetName.toLowerCase()) {
      case 'brest':
        origin = const GeographicPosition(latitude: 48.38, longitude: -4.50);
        name = 'Mercator - Rade de Brest';
        description = 'Rade de Brest, Bretagne, France (Mercator)';
        break;
      case 'mediterranean':
        origin = const GeographicPosition(latitude: 43.5, longitude: 7.0);
        name = 'Mercator - Méditerranée';
        description = 'Côte d\'Azur, France (Mercator)';
        break;
      case 'english_channel':
        origin = const GeographicPosition(latitude: 50.8, longitude: -1.1);
        name = 'Mercator - Manche';
        description = 'Portsmouth, Angleterre (Mercator)';
        break;
      case 'san_francisco':
        origin = const GeographicPosition(latitude: 37.8, longitude: -122.4);
        name = 'Mercator - San Francisco';
        description = 'Baie de San Francisco, USA (Mercator)';
        break;
      case 'sydney':
        origin = const GeographicPosition(latitude: -33.85, longitude: 151.2);
        name = 'Mercator - Sydney';
        description = 'Port de Sydney, Australie (Mercator)';
        break;
      default:
        throw ArgumentError('Preset inconnu: $presetName');
    }

    state = MercatorCoordinateSystemService(
      config: MercatorCoordinateSystemConfig(
        origin: origin,
        name: name,
        description: description,
      ),
    );
  }

  /// Auto-détecte la meilleure origine depuis les données de parcours
  void autoDetectFromCourse(List<GeographicPosition> positions) {
    if (positions.isEmpty) return;

    // Calcule le centroïde de toutes les positions
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
      name: 'Mercator Auto-détecté',
      description: 'Centroïde du parcours (Mercator)',
    );
  }
}

/// Provider pour le service de système de coordonnées Mercator
final mercatorCoordinateSystemProvider = NotifierProvider<MercatorCoordinateSystemNotifier, MercatorCoordinateSystemService>(() {
  return MercatorCoordinateSystemNotifier();
});