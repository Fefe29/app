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
import 'package:kornog/features/analysis/providers/analysis_filters.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_recorder.dart';
import 'package:kornog/domain/entities/telemetry.dart';
import 'package:kornog/features/telemetry_recording/presentation/dialogs/recording_session_dialog.dart';

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
            // Bouton unique pour afficher le dialog
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showRecordingDialog(context),
                  icon: const Icon(Icons.settings),
                  label: const Text('Gérer l\'enregistrement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RecordingSessionDialog(),
    );
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
    final selectedSessionId = ref.watch(selectedSessionProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bouton pour basculer mode temps réel / session
            if (selectedSessionId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(selectedSessionProvider.notifier).clearSelection();
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Retour au Temps Réel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          foregroundColor: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                      final isSelected = session.sessionId == selectedSessionId;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: isSelected
                              ? const Icon(Icons.check_circle, color: Colors.blue)
                              : const Icon(Icons.folder, color: Colors.grey),
                          title: Text(
                            _formatSessionTitle(session),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${session.snapshotCount} points • ${(session.sizeBytes / 1024).toStringAsFixed(1)} KB • ${_formatDuration(session.endTime.difference(session.startTime))}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            // Sélectionner la session pour charger ses données
                            ref.read(selectedSessionProvider.notifier).selectSession(session.sessionId);
                          },
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

  /// Formate le titre d'une session avec le format: YYYY-MM-DD HH:MM:SS → HH:MM:SS
  String _formatSessionTitle(SessionMetadata session) {
    final startStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(session.startTime);
    final endStr = DateFormat('HH:mm:ss').format(session.endTime);
    return '$startStr → $endStr';
  }

  /// Formate la durée: "1m 23s" ou "45s"
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

// ============================================================================
// SESSION STATS WIDGET (COMPACT - Stats clés uniquement)
// ============================================================================

class SessionStatsWidget extends ConsumerWidget {
  final String? sessionId;

  const SessionStatsWidget({
    this.sessionId,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('🎨 [SessionStatsWidget.build] sessionId=$sessionId');
    
    // Chercher si une session est en cours d'enregistrement
    final currentRecordingSessionId = ref.watch(currentRecordingSessionIdProvider);
    
    // Si on est en enregistrement, afficher les stats en temps réel
    if (currentRecordingSessionId != null) {
      print('✅ [SessionStatsWidget] Enregistrement en cours: $currentRecordingSessionId');
      final statsAsync = ref.watch(currentSessionStatsProvider);
      return statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('❌ $err')),
        data: (stats) {
          if (stats == null) {
            return const Center(child: Text('📊 En attente de données...'));
          }
          return _buildStatsCard(context, stats);
        },
      );
    }
    
    // Sinon, observer la session sélectionnée depuis selectedSessionProvider
    final selectedSessionId = ref.watch(selectedSessionProvider);
    
    // Si une session est sélectionnée (pas d'enregistrement en cours), afficher ses stats
    if (selectedSessionId != null) {
      print('📊 [SessionStatsWidget] Session sélectionnée: $selectedSessionId');
      final sessionStatsAsync = ref.watch(sessionStatsProvider(selectedSessionId));
      return sessionStatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('❌ $err')),
        data: (stats) => _buildStatsCard(context, stats),
      );
    }
    
    // Sinon si sessionId a été passé en paramètre, l'utiliser
    if (sessionId != null) {
      print('📊 [SessionStatsWidget] Session passée en paramètre: $sessionId');
      final sessionStatsAsync = ref.watch(sessionStatsProvider(sessionId!));
      return sessionStatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('❌ $err')),
        data: (stats) => _buildStatsCard(context, stats),
      );
    }
    
    // Aucune session
    return const Center(child: Text('Démarrer une session dans le menu pour voir les stats'));
  }

  Widget _buildStatsCard(BuildContext context, SessionStats stats) {
    // Format durée en mm:ss
    String formatDuration(int? seconds) {
      if (seconds == null || seconds <= 0) return '--';
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📈 Statistiques de la session',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Grille 3x2 de stats clés
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _StatCard(
                  label: 'Vitesse MAX',
                  value: '${stats.maxSpeed.toStringAsFixed(1)}',
                  unit: 'kn',
                  icon: Icons.trending_up,
                  color: Colors.red,
                ),
                _StatCard(
                  label: 'Vitesse MOY',
                  value: '${stats.avgSpeed.toStringAsFixed(1)}',
                  unit: 'kn',
                  icon: Icons.speed,
                  color: Colors.orange,
                ),
                _StatCard(
                  label: 'Enregistrement',
                  value: formatDuration(stats.durationSeconds),
                  unit: 'temps',
                  icon: Icons.timer,
                  color: Colors.purple,
                ),
                _StatCard(
                  label: 'Vent MAX',
                  value: '${stats.maxWindSpeed.toStringAsFixed(1)}',
                  unit: 'kn',
                  icon: Icons.cloud_upload,
                  color: Colors.blue,
                ),
                _StatCard(
                  label: 'Vent MIN',
                  value: '${stats.minWindSpeed.toStringAsFixed(1)}',
                  unit: 'kn',
                  icon: Icons.cloud_download,
                  color: Colors.cyan,
                ),
                _StatCard(
                  label: 'Vent MOY',
                  value: '${stats.avgWindSpeed.toStringAsFixed(1)}',
                  unit: 'kn',
                  icon: Icons.cloud,
                  color: Colors.lightBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
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
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TELEMETRY PAGE - Full details
// ============================================================================

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
