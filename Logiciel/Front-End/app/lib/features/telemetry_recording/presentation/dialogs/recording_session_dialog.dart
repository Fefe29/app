/// Dialog unique pour gérer une session d'enregistrement complète
/// Affiche les options de sélection des données et les contrôles (démarrer/pause/arrêter)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/features/telemetry_recording/models/recording_options.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_recorder.dart';

class RecordingSessionDialog extends ConsumerStatefulWidget {
  const RecordingSessionDialog({Key? key}) : super(key: key);

  @override
  ConsumerState<RecordingSessionDialog> createState() =>
      _RecordingSessionDialogState();
}

class _RecordingSessionDialogState
    extends ConsumerState<RecordingSessionDialog> {
  late RecordingOptions options;
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    options = const RecordingOptions();
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingStateProvider);
    final isActive = recordingState != RecorderState.idle;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre avec statut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '⏱️ Enregistrement',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Options de sélection (désactivées pendant l'enregistrement)
              AbsorbPointer(
                absorbing: isActive,
                child: Opacity(
                  opacity: isActive ? 0.5 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Données à enregistrer :',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CheckboxTile(
                        title: '📍 Position (GPS)',
                        subtitle: 'Latitude, longitude, altitude',
                        value: options.recordPosition,
                        onChanged: (val) {
                          setState(() {
                            options = options.copyWith(recordPosition: val);
                          });
                        },
                      ),
                      _CheckboxTile(
                        title: '💨 Vent',
                        subtitle: 'Direction et force du vent',
                        value: options.recordWind,
                        onChanged: (val) {
                          setState(() {
                            options = options.copyWith(recordWind: val);
                          });
                        },
                      ),
                      _CheckboxTile(
                        title: '🚤 Performance',
                        subtitle: 'Vitesse, cap, direction',
                        value: options.recordPerformance,
                        onChanged: (val) {
                          setState(() {
                            options = options.copyWith(recordPerformance: val);
                          });
                        },
                      ),
                      _CheckboxTile(
                        title: '⚙️ Système',
                        subtitle: 'Moteur, électrique, batterie',
                        value: options.recordSystem,
                        onChanged: (val) {
                          setState(() {
                            options = options.copyWith(recordSystem: val);
                          });
                        },
                      ),
                      _CheckboxTile(
                        title: '📊 Autres',
                        subtitle: 'Météo, marées, autres données',
                        value: options.recordOther,
                        onChanged: (val) {
                          setState(() {
                            options = options.copyWith(recordOther: val);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Profils rapides (uniquement quand inactif)
                      if (!isActive)
                        _QuickProfiles(
                          onMinimal: () {
                            setState(() {
                              options = RecordingOptions.minimal();
                            });
                          },
                          onAll: () {
                            setState(() {
                              options = RecordingOptions.all();
                            });
                          },
                          onNone: () {
                            setState(() {
                              options = RecordingOptions.none();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Résumé des données sélectionnées
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildSummary(),
              ),
              const SizedBox(height: 24),

              // Boutons d'action
              _buildActionButtons(context, recordingState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final items = <String>[];
    if (options.recordPosition) items.add('📍 Position');
    if (options.recordWind) items.add('💨 Vent');
    if (options.recordPerformance) items.add('🚤 Performance');
    if (options.recordSystem) items.add('⚙️ Système');
    if (options.recordOther) items.add('📊 Autres');

    if (items.isEmpty) {
      return Text(
        '⚠️ Aucune donnée sélectionnée',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.orange[700]),
      );
    }

    return Text(
      'Enregistrement : ${items.join(', ')}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _buildActionButtons(BuildContext context, RecorderState state) {
    if (state == RecorderState.idle) {
      // Pas en enregistrement : afficher Démarrer
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _startRecording(),
            icon: const Icon(Icons.fiber_manual_record),
            label: const Text('Démarrer'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      );
    } else {
      // En enregistrement : afficher Arrêter
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed: () => _stopRecording(context),
            icon: const Icon(Icons.stop),
            label: const Text('Arrêter'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      );
    }
  }

  Future<void> _startRecording() async {
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final recorder = ref.read(recordingStateProvider.notifier);

    print('🎬 [RecordingSessionDialog] Démarrage enregistrement: $sessionId');
    print('   Options: $options');

    try {
      await recorder.startRecording(sessionId, options);
      print('✅ [RecordingSessionDialog] Enregistrement démarré');
      if (mounted) {
        // Fermer le dialog automatiquement
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Enregistrement en cours...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ [RecordingSessionDialog] Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopRecording(BuildContext context) async {
    print('🛑 [RecordingSessionDialog] Arrêt demandé');
    final recorder = ref.read(recordingStateProvider.notifier);

    try {
      final metadata = await recorder.stopRecording();
      print('✅ [RecordingSessionDialog] Enregistrement arrêté');
      print('   Snapshots: ${metadata.snapshotCount}');

      ref.invalidate(sessionsListProvider);
      ref.invalidate(totalStorageSizeProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Enregistrement arrêté: ${metadata.snapshotCount} points',
            ),
          ),
        );
        // Rester dans le dialog et réinitialiser
        setState(() {});
      }
    } catch (e) {
      print('❌ [RecordingSessionDialog] Erreur arrêt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _CheckboxTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _CheckboxTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CheckboxListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (val) => onChanged(val ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      ),
    );
  }
}

class _QuickProfiles extends StatelessWidget {
  final VoidCallback onMinimal;
  final VoidCallback onAll;
  final VoidCallback onNone;

  const _QuickProfiles({
    required this.onMinimal,
    required this.onAll,
    required this.onNone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profils rapides :',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              OutlinedButton(
                onPressed: onMinimal,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text('Minimal'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onAll,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text('Tout'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onNone,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text('Rien'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
