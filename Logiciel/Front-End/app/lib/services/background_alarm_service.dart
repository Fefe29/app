/// Background alarm service - keeps alarm checks and sounds running even when app is minimized
import 'dart:async';
import 'dart:io';
import 'sound_player_factory.dart';
import 'sound_player.dart';

/// Global reference to sound player used in background
late SoundPlayer _backgroundSoundPlayer;

/// Initialize the background alarm service
Future<void> initializeBackgroundAlarmService() async {
  // On Android/iOS, we'll initialize the foreground service later
  // On Linux/macOS/Windows, notifications work differently
  print('ℹ️  Background alarm service initialization on ${Platform.operatingSystem}');
  _backgroundSoundPlayer = createSoundPlayer();
}

/// Start the background alarm service
Future<void> startBackgroundAlarmService() async {
  print('✅ Background alarm service ready');
  // The sound player is already initialized
  // Listeners will call playBackgroundAlarmSound when alarms trigger
}

/// Stop the background alarm service
Future<void> stopBackgroundAlarmService() async {
  print('⏹️  Background alarm service stopped');
}

/// Callback function (for future use with mobile foreground services)
@pragma('vm:entry-point')
void _backgroundAlarmCallback() {
  print('🔄 Background callback');
}

/// Play alarm sound in background (can be called from anywhere)
Future<void> playBackgroundAlarmSound(String soundType) async {
  try {
    switch (soundType) {
      case 'depth':
      case 'windShift':
        // Priority alarm - long/continuous sound
        await _backgroundSoundPlayer.playFinish();
        break;
      case 'windDrop':
      case 'windRaise':
        // Medium priority
        await _backgroundSoundPlayer.playLong();
        break;
      case 'anchor':
      case 'sleep':
        // Default alarm
        await _backgroundSoundPlayer.playMedium();
        break;
      default:
        await _backgroundSoundPlayer.playShort();
    }
    print('🔊 Background alarm sound played: $soundType');
  } catch (e) {
    print('❌ Error playing background alarm sound: $e');
  }
}

/// Update notification in background
Future<void> updateBackgroundNotification(String title, String text) async {
  // Notifications handled by OS-specific implementations
  print('📢 Notification: $title - $text');
}

/// Update telemetry notification in background (for continuous data display)
Future<void> updateBackgroundTelemetryNotification({
  required double? twd,
  required double? twa,
  required double? tws,
  required double? latitude,
  required double? longitude,
  required double? depth,
  required double? waterTemp,
  String alarmStatus = '',
}) async {
  final lines = <String>[];
  
  // Wind data
  if (twd != null || tws != null) {
    final twdStr = twd != null ? '${twd.toStringAsFixed(0)}°' : '—';
    final twsStr = tws != null ? '${tws.toStringAsFixed(1)}kt' : '—';
    lines.add('💨 TWD: $twdStr | TWS: $twsStr');
  }
  
  // Position data
  if (latitude != null && longitude != null) {
    lines.add('📍 ${latitude.toStringAsFixed(4)}°N ${longitude.toStringAsFixed(4)}°W');
  }
  
  // Depth/Water temp
  if (depth != null || waterTemp != null) {
    final depthStr = depth != null ? '${depth.toStringAsFixed(1)}m' : '—';
    final tempStr = waterTemp != null ? '${waterTemp.toStringAsFixed(1)}°C' : '—';
    lines.add('🌊 Depth: $depthStr | Temp: $tempStr');
  }
  
  // Alarm status
  if (alarmStatus.isNotEmpty) {
    lines.add('🚨 $alarmStatus');
  }
  
  final notificationText = lines.isNotEmpty 
    ? lines.join(' • ')
    : 'Monitoring telemetry data';
  
  try {
    await updateBackgroundNotification('Kornog Active', notificationText);
  } catch (e) {
    print('⚠️  Could not update notification: $e');
  }
}
