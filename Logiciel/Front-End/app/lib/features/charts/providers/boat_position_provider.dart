/// Providers pour extraire la position et l'orientation du bateau depuis la télémétrie NMEA
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../telemetry/providers/telemetry_bus_provider.dart';
import '../domain/models/geographic_position.dart';

/// Modèle pour la position du bateau
class BoatPosition {
  final double latitude;
  final double longitude;

  BoatPosition({
    required this.latitude,
    required this.longitude,
  });

  /// Convertir en GeographicPosition
  GeographicPosition toGeographicPosition() {
    return GeographicPosition(
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  String toString() => 'BoatPosition($latitude, $longitude)';
}

/// Provider pour la position du bateau (latitude, longitude)
/// Retourne null si pas de données disponibles
final boatPositionProvider = StreamProvider<BoatPosition?>((ref) async* {
  final telemetryStream = ref.watch(snapshotStreamProvider);
  
  await for (final snapshot in telemetryStream) {
    final lat = snapshot.data?['nav.lat'] as double?;
    final lon = snapshot.data?['nav.lon'] as double?;
    
    if (lat != null && lon != null) {
      yield BoatPosition(latitude: lat, longitude: lon);
    } else {
      yield null;
    }
  }
});

/// Provider pour le cap du bateau (heading)
/// Retourne null si pas de données disponibles
/// Valeur en degrés (0° = Nord, 90° = Est)
final boatHeadingProvider = StreamProvider<double?>((ref) async* {
  final telemetryStream = ref.watch(snapshotStreamProvider);
  
  await for (final snapshot in telemetryStream) {
    final heading = snapshot.data?['nav.hdg'] as double?;
    if (heading != null) {
      yield heading;
    } else {
      yield null;
    }
  }
});

/// Provider pour la vitesse du bateau (SOG - Speed Over Ground)
/// Retourne null si pas de données disponibles
/// Valeur en nœuds
final boatSpeedProvider = StreamProvider<double?>((ref) async* {
  final telemetryStream = ref.watch(snapshotStreamProvider);
  
  await for (final snapshot in telemetryStream) {
    final speed = snapshot.data?['nav.sog'] as double?;
    if (speed != null) {
      yield speed;
    } else {
      yield null;
    }
  }
});
