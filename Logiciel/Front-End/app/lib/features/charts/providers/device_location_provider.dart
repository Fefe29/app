/// Provider pour la position GPS de l'appareil (téléphone/tablette/ordinateur)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/models/geographic_position.dart';

/// Modèle pour la position de l'appareil
class DeviceLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;

  DeviceLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  GeographicPosition toGeographicPosition() {
    return GeographicPosition(
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  String toString() => 'DeviceLocation($latitude, $longitude, accuracy: $accuracy)';
}

/// Provider pour obtenir le flux continu de la position de l'appareil
/// Retourne null si pas de données disponibles ou permission refusée
final deviceLocationProvider = StreamProvider<DeviceLocation?>((ref) async* {
  // Vérifier et demander les permissions
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    // ignore: avoid_print
    print('⚠️ Permissions GPS refusées définitivement');
    yield null;
    return;
  }

  if (permission == LocationPermission.denied) {
    // ignore: avoid_print
    print('⚠️ Permissions GPS refusées');
    yield null;
    return;
  }

  // Écouter les positions en continu
  // LocationSettings avec intervalles appropriés pour un bateau
  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0, // Chaque mise à jour, pas d'attente de distance
  );

  await for (final position in Geolocator.getPositionStream(locationSettings: locationSettings)) {
    yield DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
  }
});
