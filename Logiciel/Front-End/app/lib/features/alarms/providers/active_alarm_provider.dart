/// Provider pour les alertes visuelles d'alarmes
/// Aggrège tous les types d'alarmes et expose l'alarme actuellement active
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/features/alarms/models/alarm_alert.dart';
import 'anchor_alarm_provider.dart';
import 'other_alarms_provider.dart';

/// Provider pour obtenir l'alarme actuellement déclenchée
/// Retourne null si aucune alarme n'est active
final activeAlarmProvider = Provider<AlarmAlert?>((ref) {
  final otherAlarms = ref.watch(otherAlarmsProvider);
  final anchorAlarm = ref.watch(anchorAlarmProvider);
  final now = DateTime.now();

  print('🔍 [activeAlarmProvider] Vérification alarmes:');
  print('   depth: triggered=${otherAlarms.depth.triggered}, enabled=${otherAlarms.depth.enabled}');
  print('   windShift: triggered=${otherAlarms.windShift.triggered}, enabled=${otherAlarms.windShift.enabled}');
  print('   windDrop: triggered=${otherAlarms.windDrop.triggered}, enabled=${otherAlarms.windDrop.enabled}');
  print('   windRaise: triggered=${otherAlarms.windRaise.triggered}, enabled=${otherAlarms.windRaise.enabled}');
  print('   anchor: triggered=${anchorAlarm.triggered}, enabled=${anchorAlarm.enabled}');

  // Vérifier l'alarme de profondeur
  if (otherAlarms.depth.triggered && otherAlarms.depth.enabled) {
    print('✅ [activeAlarmProvider] ALARME PROFONDEUR ACTIVE');
    return AlarmAlert(
      type: 'depth',
      title: '🌊 Alerte Profondeur',
      description: 'Profondeur dangereuse détectée!\n'
          'Profondeur: ${otherAlarms.depth.lastDepth?.toStringAsFixed(1) ?? "?"}m\n'
          'Seuil: ${otherAlarms.depth.minDepthMeters}m',
      triggeredAt: now,
    );
  }

  // Vérifier l'alarme de shift du vent
  if (otherAlarms.windShift.triggered && otherAlarms.windShift.enabled) {
    return AlarmAlert(
      type: 'windShift',
      title: '💨 Alerte Changement de Vent',
      description: 'Le vent a changé de direction!\n'
          'Changement: ${otherAlarms.windShift.currentDiffAbs?.toStringAsFixed(1) ?? "?"}°\n'
          'Seuil: ${otherAlarms.windShift.thresholdDeg}°',
      triggeredAt: now,
    );
  }

  // Vérifier l'alarme de vent faible
  if (otherAlarms.windDrop.triggered && otherAlarms.windDrop.enabled) {
    return AlarmAlert(
      type: 'windDrop',
      title: '💤 Alerte Vent Faible',
      description: 'Le vent est trop faible!\n'
          'Vent: ${otherAlarms.windDrop.lastValue?.toStringAsFixed(1) ?? "?"}kt\n'
          'Seuil: ${otherAlarms.windDrop.threshold}kt',
      triggeredAt: now,
    );
  }

  // Vérifier l'alarme de vent fort
  if (otherAlarms.windRaise.triggered && otherAlarms.windRaise.enabled) {
    return AlarmAlert(
      type: 'windRaise',
      title: '🌪️ Alerte Vent Fort',
      description: 'Le vent est trop fort!\n'
          'Vent: ${otherAlarms.windRaise.lastValue?.toStringAsFixed(1) ?? "?"}kt\n'
          'Seuil: ${otherAlarms.windRaise.threshold}kt',
      triggeredAt: now,
    );
  }

  // Vérifier l'alarme d'ancre
  if (anchorAlarm.triggered && anchorAlarm.enabled) {
    return AlarmAlert(
      type: 'anchor',
      title: '⚓ Alerte Dérive Ancre',
      description: 'Votre ancre a dérivé!\n'
          'Rayon autorisé: ${anchorAlarm.radiusMeters}m',
      triggeredAt: now,
    );
  }

  return null;
});
