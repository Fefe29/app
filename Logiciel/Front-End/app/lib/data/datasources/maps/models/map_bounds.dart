/// Modèle pour définir les limites géographiques d'une zone de carte
library;

import 'dart:math';
import '../../../../features/charts/domain/models/geographic_position.dart';

/// Délimite une zone géographique rectangulaire
class MapBounds {
  const MapBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  /// Centre de la zone
  GeographicPosition get center => GeographicPosition(
        latitude: (minLatitude + maxLatitude) / 2,
        longitude: (minLongitude + maxLongitude) / 2,
      );

  /// Largeur en degrés
  double get widthDegrees => maxLongitude - minLongitude;

  /// Hauteur en degrés
  double get heightDegrees => maxLatitude - minLatitude;

  /// Surface approximative en km²
  double get approximateAreaKm2 {
    const earthRadius = 6371.0; // Rayon de la Terre en km
    final latRadians = (minLatitude + maxLatitude) / 2 * (pi / 180);
    final widthKm = widthDegrees * (pi / 180) * earthRadius * cos(latRadians);
    final heightKm = heightDegrees * (pi / 180) * earthRadius;
    return widthKm * heightKm;
  }

  /// Vérifie si une position est dans cette zone
  bool contains(GeographicPosition position) {
    return position.latitude >= minLatitude &&
           position.latitude <= maxLatitude &&
           position.longitude >= minLongitude &&
           position.longitude <= maxLongitude;
  }

  /// Étend la zone pour inclure une position
  MapBounds expandToInclude(GeographicPosition position) {
    return MapBounds(
      minLatitude: minLatitude < position.latitude ? minLatitude : position.latitude,
      maxLatitude: maxLatitude > position.latitude ? maxLatitude : position.latitude,
      minLongitude: minLongitude < position.longitude ? minLongitude : position.longitude,
      maxLongitude: maxLongitude > position.longitude ? maxLongitude : position.longitude,
    );
  }

  /// Étend la zone avec une marge (en degrés)
  MapBounds expandBy(double marginDegrees) {
    return MapBounds(
      minLatitude: minLatitude - marginDegrees,
      maxLatitude: maxLatitude + marginDegrees,
      minLongitude: minLongitude - marginDegrees,
      maxLongitude: maxLongitude + marginDegrees,
    );
  }

  /// Crée une zone depuis une liste de positions
  static MapBounds fromPositions(List<GeographicPosition> positions) {
    if (positions.isEmpty) {
      throw ArgumentError('La liste de positions ne peut pas être vide');
    }

    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLon = positions.first.longitude;
    double maxLon = positions.first.longitude;

    for (final pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLon) minLon = pos.longitude;
      if (pos.longitude > maxLon) maxLon = pos.longitude;
    }

    return MapBounds(
      minLatitude: minLat,
      maxLatitude: maxLat,
      minLongitude: minLon,
      maxLongitude: maxLon,
    );
  }

  @override
  String toString() => 'MapBounds(${minLatitude.toStringAsFixed(4)}, ${minLongitude.toStringAsFixed(4)} → ${maxLatitude.toStringAsFixed(4)}, ${maxLongitude.toStringAsFixed(4)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapBounds &&
          runtimeType == other.runtimeType &&
          minLatitude == other.minLatitude &&
          maxLatitude == other.maxLatitude &&
          minLongitude == other.minLongitude &&
          maxLongitude == other.maxLongitude;

  @override
  int get hashCode =>
      minLatitude.hashCode ^
      maxLatitude.hashCode ^
      minLongitude.hashCode ^
      maxLongitude.hashCode;
}