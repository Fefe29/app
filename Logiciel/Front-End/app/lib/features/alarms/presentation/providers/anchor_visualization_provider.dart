import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/anchor_alarm_provider.dart';

class AnchorVisualization {
  final bool visible;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool triggered;

  AnchorVisualization({
    required this.visible,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.triggered,
  });
}

final anchorVisualizationProvider = Provider<AnchorVisualization>((ref) {
  final anchorAlarm = ref.watch(anchorAlarmProvider);

  // L'ancre est visible si une position a été définie (pas besoin du toggle)
  final hasAnchorPosition = anchorAlarm.anchorLat != null && anchorAlarm.anchorLon != null;

  print('📍 anchorVisualizationProvider - hasPosition: $hasAnchorPosition, lat: ${anchorAlarm.anchorLat}, lon: ${anchorAlarm.anchorLon}, radius: ${anchorAlarm.radiusMeters}, alarmEnabled: ${anchorAlarm.enabled}, triggered: ${anchorAlarm.triggered}');

  return AnchorVisualization(
    visible: hasAnchorPosition,  // Affiche l'ancre si position définie
    latitude: anchorAlarm.anchorLat ?? 0.0,
    longitude: anchorAlarm.anchorLon ?? 0.0,
    radiusMeters: anchorAlarm.radiusMeters.toDouble(),
    triggered: anchorAlarm.triggered && anchorAlarm.enabled,  // Alarme rouge seulement si enabled ET triggered
  );
});
