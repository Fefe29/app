/// Background alarm sound trigger provider
/// Listens to active alarms and plays background sounds when they trigger
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/services/background_alarm_service.dart';
import 'active_alarm_provider.dart';

/// Provider that listens to active alarms and triggers background sounds
/// This runs a background listener that plays sounds even when app is minimized
final backgroundAlarmSoundProvider = Provider<void>((ref) {
  final activeAlarm = ref.watch(activeAlarmProvider);

  // When an alarm becomes active, play the background sound
  ref.listen(activeAlarmProvider, (previous, next) {
    // Only trigger if alarm changed from none to active
    if (previous == null && next != null) {
      print('🔊 Alarm triggered: ${next.type}');
      playBackgroundAlarmSound(next.type);
      
      // Update the notification text
      updateBackgroundNotification(
        'Kornog Alarm Active',
        next.title,
      );
    }
  });
});
