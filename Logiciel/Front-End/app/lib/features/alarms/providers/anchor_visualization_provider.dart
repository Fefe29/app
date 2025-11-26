/// Provider pour la visualisation de l'ancre sur la carte
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/anchor_alarm_provider.dart';

/// Représente les données de visualisation de l'ancre
class AnchorVisualization {
  final bool visible;      // Si l'ancre doit être affichée
  final double? latitude;  // Latitude de l'ancre
  final double? longitude; // Longitude de l'ancre
  final double radiusMeters; // Rayon de la zone de mouillage
  final bool triggered;    // Si l'alarme est déclenchée

  const AnchorVisualization({
    required this.visible,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.triggered,
  });
}

/// Provider pour obtenir les données de visualisation de l'ancre
final anchorVisualizationProvider = Provider<AnchorVisualization>((ref) {
  final anchorState = ref.watch(anchorAlarmProvider);
  
  return AnchorVisualization(
    visible: anchorState.enabled && anchorState.anchorLat != null && anchorState.anchorLon != null,
    latitude: anchorState.anchorLat,
    longitude: anchorState.anchorLon,
    radiusMeters: anchorState.radiusMeters,
    triggered: anchorState.triggered,
  );
});
