/// Anchor alarm providers.
/// See ARCHITECTURE_DOCS.md (section: anchor_alarm_provider.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' show sqrt, cos, pi;
import '../../../services/sound_player_factory.dart';
import '../../../services/sound_player.dart';

class AnchorAlarmState {
  final bool enabled;
  final double radiusMeters;
  final double? anchorLat;
  final double? anchorLon;
  final bool triggered;
  const AnchorAlarmState({
    required this.enabled,
    required this.radiusMeters,
    this.anchorLat,
    this.anchorLon,
    required this.triggered,
  });

  AnchorAlarmState copyWith({
    bool? enabled,
    double? radiusMeters,
    double? anchorLat,
    double? anchorLon,
    bool? triggered,
  }) => AnchorAlarmState(
        enabled: enabled ?? this.enabled,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        anchorLat: anchorLat ?? this.anchorLat,
        anchorLon: anchorLon ?? this.anchorLon,
        triggered: triggered ?? this.triggered,
      );
}

class AnchorAlarmNotifier extends Notifier<AnchorAlarmState> {
  final SoundPlayer _sound = createSoundPlayer();

  @override
  AnchorAlarmState build() => const AnchorAlarmState(enabled: false, radiusMeters: 30, triggered: false);

  void toggle(bool v) => state = state.copyWith(enabled: v, triggered: v ? state.triggered : false);
  void setRadius(double r) => state = state.copyWith(radiusMeters: r);
  void setAnchorPosition(double lat, double lon) => state = state.copyWith(anchorLat: lat, anchorLon: lon);

  void updateCurrentPosition(double lat, double lon) {
    if (!state.enabled || state.anchorLat == null || state.anchorLon == null) return;
    final d = _distanceMeters(state.anchorLat!, state.anchorLon!, lat, lon);
    if (d > state.radiusMeters && !state.triggered) {
      // Alarme dérive ancre : bip double
      _sound.playDoubleShort();
      state = state.copyWith(triggered: true);
    }
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    // Formule haversine simplifiée
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = 0.5 - cos(dLat)/2 +
        cos(lat1 * pi/180) * cos(lat2 * pi/180) * (1 - cos(dLon)) / 2;
    return 12742000 * sqrt(a); // 2 * R(6371000) * asin(sqrt(a)) ~ optimisé
  }
}

final anchorAlarmProvider = NotifierProvider<AnchorAlarmNotifier, AnchorAlarmState>(AnchorAlarmNotifier.new);
