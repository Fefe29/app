/// Widget overlay pour afficher les alertes d'alarmes sur n'importe quelle page
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/features/alarms/models/alarm_alert.dart';
import 'package:kornog/features/alarms/providers/active_alarm_provider.dart';

// Re-exports pour faciliter l'import
export 'package:kornog/features/alarms/models/alarm_alert.dart';
export 'package:kornog/features/alarms/providers/active_alarm_provider.dart';

/// Widget qui affiche une notification quand une alarme se déclenche
/// À placer dans la racine de l'application pour être visible partout
class AlarmAlertOverlay extends ConsumerStatefulWidget {
  const AlarmAlertOverlay({Key? key}) : super(key: key);

  @override
  ConsumerState<AlarmAlertOverlay> createState() => _AlarmAlertOverlayState();
}

class _AlarmAlertOverlayState extends ConsumerState<AlarmAlertOverlay> {
  AlarmAlert? _displayedAlarm;
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    print('🔔 [AlarmAlertOverlay] initState');
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser ref.listen pour détecter les changements d'alarme
    ref.listen<AlarmAlert?>(activeAlarmProvider, (previous, next) {
      print('🔔 [AlarmAlertOverlay] Alarme change: $previous → $next');
      
      // Si une alarme s'est déclenchée ET on n'affiche pas déjà un dialog
      if (next != null && !_isShowingDialog) {
        print('🔔 [AlarmAlertOverlay] Affichage de l\'alarme: ${next.type}');
        _displayedAlarm = next;
        _isShowingDialog = true;
        
        // Trouver le ScaffoldMessenger pour afficher une snackbar
        try {
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger != null) {
            _showAlarmAlert(context, next, messenger);
          }
        } catch (e) {
          print('❌ [AlarmAlertOverlay] Pas de ScaffoldMessenger: $e');
          _isShowingDialog = false;
        }
      }
    });

    return const SizedBox.shrink();
  }

  void _showAlarmAlert(BuildContext context, AlarmAlert alarm, ScaffoldMessengerState messenger) {
    print('🔔 [AlarmAlertOverlay] _showAlarmAlert appelée pour: ${alarm.type}');
    
    // Afficher une snackbar avec le message d'alarme
    messenger.showSnackBar(
      SnackBar(
        content: Text(alarm.title),
        backgroundColor: _getColorForAlarmType(alarm.type),
        duration: const Duration(hours: 1), // Rester visible jusqu'à ce qu'on la ferme manuellement
        action: SnackBarAction(
          label: 'Fermer',
          onPressed: () {
            print('🔔 [AlarmAlertOverlay] Fermeture de l\'alarme');
            _isShowingDialog = false;
            _displayedAlarm = null;
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Color _getColorForAlarmType(String type) {
    switch (type) {
      case 'depth':
        return Colors.redAccent;
      case 'windShift':
        return Colors.orangeAccent;
      case 'windDrop':
        return Colors.blueAccent;
      case 'windRaise':
        return Colors.purpleAccent;
      case 'anchor':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }
}
