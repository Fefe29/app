/// Background telemetry provider - updates the foreground notification with live data
/// This keeps the notification updated with wind, position, depth data even when app is minimized
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/providers.dart';
import 'package:kornog/services/background_alarm_service.dart';
import 'active_alarm_provider.dart';

/// Provider that listens to telemetry stream and updates background notification
/// This runs continuously and updates the foreground service notification
final backgroundTelemetryProvider = Provider<void>((ref) {
  // Watch the telemetry snapshot stream
  final snapshotAsync = ref.watch(snapshotStreamProvider);
  
  // Watch the active alarm
  final activeAlarm = ref.watch(activeAlarmProvider);

  // Update notification whenever telemetry changes
  snapshotAsync.whenData((snapshot) {
    // Extract values from metric keys (e.g. "wind.twd", "nav.position.latitude")
    final twd = snapshot.metrics['wind.twd']?.value;
    final twa = snapshot.metrics['wind.twa']?.value;
    final tws = snapshot.metrics['wind.tws']?.value;
    final latitude = snapshot.metrics['nav.position.latitude']?.value;
    final longitude = snapshot.metrics['nav.position.longitude']?.value;
    final depth = snapshot.metrics['env.depth']?.value;
    final waterTemp = snapshot.metrics['env.waterTemp']?.value;

    // Build alarm status string if any alarm is active
    String alarmStatus = '';
    if (activeAlarm != null) {
      alarmStatus = activeAlarm.title.split('\n').first; // Just the title line
    }

    // Update the notification with all telemetry data
    updateBackgroundTelemetryNotification(
      twd: twd,
      twa: twa,
      tws: tws,
      latitude: latitude,
      longitude: longitude,
      depth: depth,
      waterTemp: waterTemp,
      alarmStatus: alarmStatus,
    );

    print('📊 Background notification updated - TWS: ${tws?.toStringAsFixed(1) ?? "?"}kt, Depth: ${depth?.toStringAsFixed(1) ?? "?"}m');
  });
});
