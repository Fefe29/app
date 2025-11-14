/// Widgets réutilisables pour la télémétrie dans l'analyse
/// 
/// Composants modulaires pour :
/// - Contrôles d'enregistrement (start/stop/pause)
/// - Gestion des sessions (lister, supprimer, exporter)
/// - Statistiques clés (vitesse max, vent moyen, etc.) - format compact

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_recorder.dart';
import 'package:kornog/domain/entities/telemetry.dart';

// ============================================================================
// RECORDING CONTROLS WIDGET
// ============================================================================

class RecordingControlsWidget extends ConsumerWidget {
  const RecordingControlsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingStateProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⏱️ Enregistrement',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Status indicator
            _StatusIndicator(state: recordingState),
            const SizedBox(height: 16),
            // Control buttons
            Row(
              children: [
                if (recordingState == RecorderState.idle)
                  ElevatedButton.icon(
                    onPressed: () => _startRecording(context, ref),
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Démarrer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  )
                else if (recordingState == RecorderState.recording)
                  ElevatedButton.icon(
                    onPressed: () => _stopRecording(context, ref),
                    icon: const Icon(Icons.stop),
                    label: const Text('Arrêter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                if (recordingState == RecorderState.recording) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _pauseRecording(ref),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                ]
                else if (recordingState == RecorderState.paused) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _resumeRecording(ref),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Reprendre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording(BuildContext context, WidgetRef ref) async {
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final recorder = ref.read(recordingStateProvider.notifier);
    
    try {
      await recorder.startRecording(sessionId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Enregistrement démarré: $sessionId')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopRecording(BuildContext context, WidgetRef ref) async {
    final recorder = ref.read(recordingStateProvider.notifier);
    
    try {
      final metadata = await recorder.stopRecording();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Enregistrement arrêté: ${metadata.snapshotCount} points')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _pauseRecording(WidgetRef ref) {
    ref.read(recordingStateProvider.notifier).pauseRecording();
  }

  void _resumeRecording(WidgetRef ref) {
    ref.read(recordingStateProvider.notifier).resumeRecording();
  }
}

// ============================================================================
// SESSION MANAGEMENT WIDGET
// ============================================================================

class SessionManagementWidget extends ConsumerWidget {
  const SessionManagementWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsListProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📂 Gestion des sessions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: sessionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Center(child: Text('❌ $err')),
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const Center(child: Text('Aucune session'));
                  }
                  
                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return ListTile(
                        title: Text(session.sessionId),
                        subtitle: Text(
                          '${session.snapshotCount} points • ${(session.sizeBytes / 1024).toStringAsFixed(1)} KB',
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Exporter CSV'),
                              onTap: () => _exportSession(context, ref, session.sessionId, 'csv'),
                            ),
                            PopupMenuItem(
                              child: const Text('Exporter JSON'),
                              onTap: () => _exportSession(context, ref, session.sessionId, 'json'),
                            ),
                            PopupMenuItem(
                              child: const Text('Supprimer'),
                              onTap: () => _deleteSession(context, ref, session.sessionId),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSession(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    String format,
  ) async {
    try {
      final management = ref.read(sessionManagementProvider);
      await management.exportSession(
        sessionId: sessionId,
        format: format,
        outputPath: '/tmp',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Session exportée en $format')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur export: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteSession(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
  ) async {
    try {
      final management = ref.read(sessionManagementProvider);
      await management.deleteSession(sessionId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Session supprimée')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur suppression: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ============================================================================
// SESSION STATS WIDGET (COMPACT - Stats clés uniquement)
// ============================================================================

class SessionStatsWidget extends ConsumerWidget {
  final String sessionId;

  const SessionStatsWidget({
    required this.sessionId,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStatsAsync = ref.watch(sessionStatsProvider(sessionId));

    return sessionStatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('❌ $err')),
      data: (stats) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📈 Statistiques de la session',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                // Grille 2x2 de stats clés
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _StatCard(
                      label: 'Vitesse MAX',
                      value: '${stats.maxSpeed.toStringAsFixed(1)} kn',
                      icon: Icons.trending_up,
                      color: Colors.red,
                    ),
                    _StatCard(
                      label: 'Vitesse MOY',
                      value: '${stats.avgSpeed.toStringAsFixed(1)} kn',
                      icon: Icons.speed,
                      color: Colors.orange,
                    ),
                    _StatCard(
                      label: 'Vent MOY',
                      value: '${stats.avgWindSpeed.toStringAsFixed(1)} kn',
                      icon: Icons.cloud,
                      color: Colors.blue,
                    ),
                    _StatCard(
                      label: 'Durée / Points',
                      value: '${stats.snapshotCount} pts',
                      icon: Icons.data_usage,
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

class _StatusIndicator extends StatelessWidget {
  final RecorderState state;

  const _StatusIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (state) {
      RecorderState.idle => (Colors.grey, '⏹️ Inactif'),
      RecorderState.recording => (Colors.red, '🔴 Enregistrement'),
      RecorderState.paused => (Colors.orange, '⏸️ En pause'),
      RecorderState.error => (Colors.red[700], '❌ Erreur'),
    };

    return Chip(
      avatar: CircleAvatar(backgroundColor: color),
      label: Text(text),
      backgroundColor: color?.withOpacity(0.2),
    );
  }
}
