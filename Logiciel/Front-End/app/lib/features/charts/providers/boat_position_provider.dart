/// Providers pour extraire la position et l'orientation du bateau depuis la télémétrie NMEA ou GPS device
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/providers/app_providers.dart';
import '../../../common/providers/telemetry_providers.dart';
import '../../../config/telemetry_config.dart';
import '../domain/models/geographic_position.dart';
import 'position_source_provider.dart';
import 'device_location_provider.dart';

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
/// Retourne la position depuis NMEA ou depuis le GPS de l'appareil selon la sélection
/// En mode Simulation, retourne TOUJOURS la position NMEA (simulée)
/// Retourne null si pas de données disponibles
final boatPositionProvider = StreamProvider<BoatPosition?>((ref) async* {
  // En mode Simulation, utiliser TOUJOURS NMEA
  final sourceModeAsync = ref.watch(telemetrySourceModeProvider);
  final sourceMode = sourceModeAsync.maybeWhen(
    data: (mode) => mode,
    orElse: () => TelemetrySourceMode.fake, // Par défaut simulation
  );
  
  // Si on est en simulation, forcer NMEA
  if (sourceMode == TelemetrySourceMode.fake) {
    final telemetryBus = ref.watch(telemetryBusProvider);
    await for (final snapshot in telemetryBus.snapshots()) {
      final latMeasure = snapshot.metrics['nav.lat'];
      final lonMeasure = snapshot.metrics['nav.lon'];
      
      if (latMeasure != null && lonMeasure != null) {
        yield BoatPosition(latitude: latMeasure.value, longitude: lonMeasure.value);
      } else {
        yield null;
      }
    }
  } else {
    // Mode Réseau: respecter la sélection de source (NMEA ou GPS device)
    final positionSource = ref.watch(positionSourceProvider);
    
    if (positionSource == PositionSource.device) {
      // Utiliser la position de l'appareil (GPS du téléphone/tablette)
      final deviceLocationAsync = ref.watch(deviceLocationProvider);
      
      // deviceLocationAsync est un AsyncValue<DeviceLocation?>
      // Utiliser whenData pour extraire la valeur
      final boatPos = deviceLocationAsync.whenData((location) {
        if (location != null) {
          return BoatPosition(latitude: location.latitude, longitude: location.longitude);
        }
        return null;
      });
      
      // Extraire la position s'il y a une valeur
      if (boatPos.hasValue) {
        yield boatPos.value;
      } else {
        yield null;
      }
    } else {
      // Utiliser NMEA (depuis telemetry bus)
      final telemetryBus = ref.watch(telemetryBusProvider);
      
      await for (final snapshot in telemetryBus.snapshots()) {
        // TelemetrySnapshot contient metrics, pas data
        final latMeasure = snapshot.metrics['nav.lat'];
        final lonMeasure = snapshot.metrics['nav.lon'];
        
        if (latMeasure != null && lonMeasure != null) {
          yield BoatPosition(latitude: latMeasure.value, longitude: lonMeasure.value);
        } else {
          yield null;
        }
      }
    }
  }
});

/// Provider pour le cap du bateau (heading)
/// Retourne null si pas de données disponibles
/// Valeur en degrés (0° = Nord, 90° = Est)
final boatHeadingProvider = StreamProvider<double?>((ref) async* {
  final telemetryBus = ref.watch(telemetryBusProvider);
  
  await for (final snapshot in telemetryBus.snapshots()) {
    final hdgMeasure = snapshot.metrics['nav.hdg'];
    if (hdgMeasure != null) {
      yield hdgMeasure.value;
    } else {
      yield null;
    }
  }
});

/// Provider pour la vitesse du bateau (SOG - Speed Over Ground)
/// Retourne null si pas de données disponibles
/// Valeur en nœuds
final boatSpeedProvider = StreamProvider<double?>((ref) async* {
  final telemetryBus = ref.watch(telemetryBusProvider);
  
  await for (final snapshot in telemetryBus.snapshots()) {
    final sogMeasure = snapshot.metrics['nav.sog'];
    if (sogMeasure != null) {
      yield sogMeasure.value;
    } else {
      yield null;
    }
  }
});
