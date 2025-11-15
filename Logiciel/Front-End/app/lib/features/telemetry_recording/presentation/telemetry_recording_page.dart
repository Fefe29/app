/// Widget exemple complet pour l'enregistrement et l'analyse de sessions télémétrie.
/// 
/// Montre un cas d'usage réel : interface d'enregistrement + liste + détails.
/// À adapter selon ton UI existante.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';

/// Page principale pour l'enregistrement et gestion des sessions
class TelemetryRecordingPage extends ConsumerWidget {
  const TelemetryRecordingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enregistrement Télémétrie'),
      ),
      body: Column(
        children: [
          // Contrôles d'enregistrement
          _RecordingControls(recordingState: recordingState),
          const Divider(),
          // Liste des sessions
          Expanded(
            child: _SessionsList(),
          ),
        ],
      ),
    );
  }
}

/// Contrôles pour démarrer/arrêter l'enregistrement
class _RecordingControls extends ConsumerWidget {
  final RecorderState recordingState;

  const _RecordingControls({required this.recordingState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorder = ref.watch(telemetryRecorderProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // État actuel
          Row(
            children: [
              _StatusIndicator(state: recordingState),
              const SizedBox(width: 12),
              Text(
                _getStateLabel(recordingState),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Durée écoulée (si en cours)
          if (recordingState == RecorderState.recording && recorder != null)
            Text(
              'Durée: ${recorder.elapsedTime.inSeconds}s',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

          const SizedBox(height: 16),

          // Boutons d'action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Démarrer
              ElevatedButton.icon(
                onPressed: recordingState == RecorderState.idle
                    ? () async {
                        final sessionId =
                            'session_${DateTime.now().millisecondsSinceEpoch}';
                        try {
                          await ref
                              .read(recordingStateProvider.notifier)
                              .startRecording(sessionId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Enregistrement: $sessionId'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Démarrer'),
              ),

              // Pause/Reprendre
              if (recordingState != RecorderState.idle)
                ElevatedButton.icon(
                  onPressed: recordingState == RecorderState.recording
                      ? () {
                          ref
                              .read(recordingStateProvider.notifier)
                              .pauseRecording();
                        }
                      : recordingState == RecorderState.paused
                          ? () {
                              ref
                                  .read(recordingStateProvider.notifier)
                                  .resumeRecording();
                            }
                          : null,
                  icon: Icon(
                    recordingState == RecorderState.recording
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    recordingState == RecorderState.recording
                        ? 'Pause'
                        : 'Reprendre',
                  ),
                ),

              // Arrêter
              ElevatedButton.icon(
                onPressed: recordingState != RecorderState.idle
                    ? () async {
                        try {
                          final metadata = await ref
                              .read(recordingStateProvider.notifier)
                              .stopRecording();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Session sauvegardée: ${metadata.snapshotCount} points',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.stop),
                label: const Text('Arrêter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStateLabel(RecorderState state) {
    switch (state) {
      case RecorderState.idle:
        return 'Arrêté';
      case RecorderState.recording:
        return 'Enregistrement en cours...';
      case RecorderState.paused:
        return 'Enregistrement en pause';
      case RecorderState.error:
        return 'Erreur';
    }
  }
}

/// Indicateur de statut visuel
class _StatusIndicator extends StatelessWidget {
  final RecorderState state;

  const _StatusIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (state) {
      case RecorderState.idle:
        color = Colors.grey;
        break;
      case RecorderState.recording:
        color = Colors.red;
        break;
      case RecorderState.paused:
        color = Colors.orange;
        break;
      case RecorderState.error:
        color = Colors.red[900] ?? Colors.red;
        break;
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

/// Liste des sessions enregistrées
class _SessionsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsListProvider);
    final totalSizeAsync = ref.watch(totalStorageSizeProvider);

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(
        child: Text('Erreur: $err'),
      ),
      data: (sessions) {
        return Column(
          children: [
            // En-tête avec espace total
            Padding(
              padding: const EdgeInsets.all(12),
              child: totalSizeAsync.when(
                data: (totalSize) => Text(
                  'Espace utilisé: ${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            // Liste des sessions
            Expanded(
              child: sessions.isEmpty
                  ? const Center(
                      child: Text('Aucune session enregistrée'),
                    )
                  : ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return _SessionTile(session: session);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Tuile pour une session
class _SessionTile extends ConsumerWidget {
  final SessionMetadata session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(sessionStatsProvider(session.sessionId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ExpansionTile(
        title: Text(session.sessionId),
        subtitle: Text(
          '${session.snapshotCount} points • '
          '${(session.sizeBytes / 1024).toStringAsFixed(1)} KB',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: statsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (err, st) => Text('Erreur: $err'),
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatRow('Vitesse moyenne', stats.avgSpeed, 'kn'),
                  _StatRow('Vitesse max', stats.maxSpeed, 'kn'),
                  _StatRow('Vitesse min', stats.minSpeed, 'kn'),
                  _StatRow('Vent moyen', stats.avgWindSpeed, 'kn'),
                  const SizedBox(height: 16),
                  Text(
                    'Période: ${session.startTime} → ${session.endTime}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Analyser
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  _SessionDetailPage(sessionId: session.sessionId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics),
                        label: const Text('Analyser'),
                      ),

                      // Exporter
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            // Exemple export CSV
                            final timestamp = DateTime.now().millisecondsSinceEpoch;
                            final outputPath =
                                '/sdcard/Download/${session.sessionId}_$timestamp.csv';

                            await ref
                                .read(sessionManagementProvider)
                                .exportSession(
                                  sessionId: session.sessionId,
                                  format: 'csv',
                                  outputPath: outputPath,
                                );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Exportée: $outputPath'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur export: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Exporter'),
                      ),

                      // Supprimer
                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Supprimer?'),
                              content: Text(
                                'Supprimer la session ${session.sessionId}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Supprimer'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            await ref
                                .read(sessionManagementProvider)
                                .deleteSession(session.sessionId);
                          }
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Supprimer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de stat (clé-valeur avec unité)
class _StatRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;

  const _StatRow(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Page de détail et d'analyse d'une session
class _SessionDetailPage extends ConsumerWidget {
  final String sessionId;

  const _SessionDetailPage({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionDataAsync = ref.watch(sessionDataProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionId),
      ),
      body: sessionDataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Erreur: $err')),
        data: (snapshots) {
          return ListView(
            children: [
              // Résumé
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Snapshots: ${snapshots.length}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (snapshots.isNotEmpty)
                      Text(
                        'Durée: ${snapshots.last.ts.difference(snapshots.first.ts).inSeconds}s',
                      ),
                  ],
                ),
              ),

              // Tableau des snapshots
              DataTable(
                columns: const [
                  DataColumn(label: Text('Temps')),
                  DataColumn(label: Text('SOG (kn)')),
                  DataColumn(label: Text('TWD (°)')),
                ],
                rows: snapshots.take(50).map((snapshot) {
                  final sog = snapshot.metrics['nav.sog']?.value ?? 0;
                  final twd = snapshot.metrics['wind.twd']?.value ?? 0;
                  return DataRow(cells: [
                    DataCell(Text(snapshot.ts.toString().split('.').first)),
                    DataCell(Text(sog.toStringAsFixed(1))),
                    DataCell(Text(twd.toStringAsFixed(0))),
                  ]);
                }).toList(),
              ),

              if (snapshots.length > 50)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '... et ${snapshots.length - 50} autres snapshots',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
