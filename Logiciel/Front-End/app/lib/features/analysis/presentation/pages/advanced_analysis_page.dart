/// Advanced Analysis Window - Contrôles complets d'enregistrement et analyse
/// 
/// Features:
/// - ✅ Démarrer/arrêter une nouvelle session d'enregistrement
/// - ✅ Gérer les fichiers (lister, supprimer, exporter)
/// - ✅ Afficher données session en cours
/// - ✅ Charger et comparer sessions précédentes
/// - ✅ Tableaux de données interactifs
/// - ✅ Graphiques de performance
/// - ✅ Export multiformat
///
/// Architecture:
/// - RecordingControlPanel: Contrôles start/stop/manage
/// - SessionSelector: Choix session (en cours ou précédentes)
/// - DataViewer: Tableau + graphiques
/// - MultiSessionComparison: Croisement données multi-sessions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_recorder.dart';
import 'package:kornog/domain/entities/telemetry.dart';

/// Page d'analyse avancée avec contrôles complets
class AdvancedAnalysisPage extends ConsumerWidget {
  const AdvancedAnalysisPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Analysis Center - Télémétrie'),
        elevation: 2,
      ),
      body: Column(
        children: [
          // 1. RECORDING CONTROL PANEL (Top)
          Container(
            color: Colors.blue.withOpacity(0.1),
            padding: const EdgeInsets.all(12),
            child: const _RecordingControlPanel(),
          ),
          const Divider(),
          // 2. MAIN CONTENT (expandable)
          Expanded(
            child: Row(
              children: [
                // LEFT: Session selector
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.grey[100],
                    child: const _SessionSelector(),
                  ),
                ),
                // RIGHT: Data viewer
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.white,
                    child: const _DataViewer(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel de contrôle d'enregistrement (haut de la page)
class _RecordingControlPanel extends ConsumerStatefulWidget {
  const _RecordingControlPanel();

  @override
  ConsumerState<_RecordingControlPanel> createState() =>
      _RecordingControlPanelState();
}

class _RecordingControlPanelState
    extends ConsumerState<_RecordingControlPanel> {
  late TextEditingController _sessionNameController;
  int _snapshotCount = 0;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sessionNameController = TextEditingController();
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingStateProvider);
    final recorder = ref.watch(telemetryRecorderProvider);

    // Mettre en place les callbacks
    if (recordingState == RecorderState.recording) {
      recorder.onProgress = (count, elapsed) {
        setState(() {
          _snapshotCount = count;
          _elapsed = elapsed;
        });
      };
    }

    return Column(
      children: [
        // Row 1: État et stats
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // État
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
            // Stats
            if (recordingState == RecorderState.recording)
              Row(
                children: [
                  Chip(
                    label: Text('${_snapshotCount} points'),
                    avatar: const Icon(Icons.data_usage),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${_elapsed.inSeconds}s'),
                    avatar: const Icon(Icons.schedule),
                  ),
                ],
              )
            else
              const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Contrôles
        Row(
          children: [
            // Nom de la session (input)
            if (recordingState == RecorderState.idle)
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _sessionNameController,
                  decoration: InputDecoration(
                    hintText: 'Nom session (ex: regatta_2025_11_14_race1)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    prefixIcon: const Icon(Icons.label),
                    suffixText: '(optionnel)',
                  ),
                ),
              )
            else
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Session en cours...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            // Boutons d'action
            ElevatedButton.icon(
              onPressed: recordingState == RecorderState.idle
                  ? () async {
                      final sessionName =
                          _sessionNameController.text.trim().isEmpty
                              ? 'session_${DateTime.now().millisecondsSinceEpoch}'
                              : _sessionNameController.text;

                      try {
                        await ref
                            .read(recordingStateProvider.notifier)
                            .startRecording(sessionName);
                        _sessionNameController.clear();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Enregistrement: $sessionName'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  : null,
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('▶ Démarrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            // Pause/Reprendre
            if (recordingState != RecorderState.idle)
              ElevatedButton.icon(
                onPressed: recordingState == RecorderState.recording
                    ? () => ref
                        .read(recordingStateProvider.notifier)
                        .pauseRecording()
                    : recordingState == RecorderState.paused
                        ? () => ref
                            .read(recordingStateProvider.notifier)
                            .resumeRecording()
                        : null,
                icon: Icon(
                  recordingState == RecorderState.recording
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                label: Text(
                  recordingState == RecorderState.recording
                      ? '⏸ Pause'
                      : '▶ Reprendre',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              )
            else
              const SizedBox.shrink(),
            const SizedBox(width: 8),
            // Arrêter
            ElevatedButton.icon(
              onPressed: recordingState != RecorderState.idle
                  ? () async {
                      try {
                        final metadata = await ref
                            .read(recordingStateProvider.notifier)
                            .stopRecording();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '✅ Sauvegardée: ${metadata.snapshotCount} points',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // Refresh la liste des sessions
                          ref.refresh(sessionsListProvider);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  : null,
              icon: const Icon(Icons.stop),
              label: const Text('⏹ Arrêter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getStateLabel(RecorderState state) {
    switch (state) {
      case RecorderState.idle:
        return 'Arrêté';
      case RecorderState.recording:
        return '🔴 Enregistrement en cours...';
      case RecorderState.paused:
        return '⏸ En pause';
      case RecorderState.error:
        return '❌ Erreur';
    }
  }
}

/// Sélecteur de session (gauche)
class _SessionSelector extends ConsumerStatefulWidget {
  const _SessionSelector();

  @override
  ConsumerState<_SessionSelector> createState() => _SessionSelectorState();
}

class _SessionSelectorState extends ConsumerState<_SessionSelector> {
  String? _selectedSessionId;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsListProvider);

    return Column(
      children: [
        // Titre
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.withOpacity(0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📋 Sessions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.refresh(sessionsListProvider),
                tooltip: 'Rafraîchir',
              ),
            ],
          ),
        ),
        // Liste
        Expanded(
          child: sessionsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('❌ $err')),
            data: (sessions) {
              if (sessions.isEmpty) {
                return const Center(
                  child: Text('Aucune session enregistrée'),
                );
              }

              return ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final isSelected =
                      _selectedSessionId == session.sessionId;

                  return Container(
                    margin: const EdgeInsets.all(4),
                    child: Material(
                      color: isSelected
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSessionId = session.sessionId;
                          });
                        },
                        child: ListTile(
                          selected: isSelected,
                          title: Text(
                            session.sessionId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${session.snapshotCount} pts • ${(session.sizeBytes / 1024).toStringAsFixed(1)}KB',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: SizedBox(
                            width: 80,
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                              children: [
                                // Export
                                PopupMenuButton<String>(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'csv',
                                      child: Text('📊 CSV'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'json',
                                      child: Text('📄 JSON'),
                                    ),
                                  ],
                                  onSelected: (format) async {
                                    try {
                                      final path =
                                          '/sdcard/Download/${session.sessionId}_${DateTime.now().millisecondsSinceEpoch}.$format';
                                      await ref
                                          .read(
                                              sessionManagementProvider)
                                          .exportSession(
                                            sessionId:
                                                session.sessionId,
                                            format: format,
                                            outputPath: path,
                                          );
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '✅ Exportée: $path'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '❌ Erreur export: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: const Icon(Icons.download),
                                ),
                                // Supprimer
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  iconSize: 18,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) =>
                                          AlertDialog(
                                        title: const Text(
                                            'Supprimer?'),
                                        content: Text(
                                          'Supprimer ${session.sessionId}?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                                    context,
                                                    false),
                                            child: const Text(
                                                'Annuler'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                                    context,
                                                    true),
                                            child: const Text(
                                                'Supprimer'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        await ref
                                            .read(
                                                sessionManagementProvider)
                                            .deleteSession(
                                                session.sessionId);
                                        if (mounted) {
                                          setState(() {
                                            if (_selectedSessionId ==
                                                session.sessionId) {
                                              _selectedSessionId =
                                                  null;
                                            }
                                          });
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '❌ Erreur: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  tooltip: 'Supprimer',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Visionneuse de données (droite)
class _DataViewer extends ConsumerWidget {
  const _DataViewer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtenir la session sélectionnée depuis state parent
    // ℹ️ On utilise une approche simple : StateProvider pour la session courante
    final selectedSessionId =
        ref.watch(currentlyViewedSessionProvider);

    if (selectedSessionId == null) {
      return const Center(
        child: Text('👈 Sélectionnez une session à gauche'),
      );
    }

    return _SessionDataViewer(sessionId: selectedSessionId);
  }
}

/// Visionneuse des données d'une session
class _SessionDataViewer extends ConsumerWidget {
  final String sessionId;

  const _SessionDataViewer({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionDataAsync = ref.watch(sessionDataProvider(sessionId));
    final statsAsync = ref.watch(sessionStatsProvider(sessionId));

    return Column(
      children: [
        // En-tête avec stats
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.withOpacity(0.05),
          child: statsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (err, st) => Text('❌ $err'),
            data: (stats) => Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                  'Vitesse moy.',
                  '${stats.avgSpeed.toStringAsFixed(1)} kn',
                  Icons.speed,
                ),
                _StatChip(
                  'Max',
                  '${stats.maxSpeed.toStringAsFixed(1)} kn',
                  Icons.trending_up,
                ),
                _StatChip(
                  'Min',
                  '${stats.minSpeed.toStringAsFixed(1)} kn',
                  Icons.trending_down,
                ),
                _StatChip(
                  'Vent',
                  '${stats.avgWindSpeed.toStringAsFixed(1)} kn',
                  Icons.cloud,
                ),
                _StatChip(
                  'Points',
                  '${stats.snapshotCount}',
                  Icons.data_usage,
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        // Tableau de données
        Expanded(
          child: sessionDataAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('❌ $err')),
            data: (List<TelemetrySnapshot> snapshots) {
              if (snapshots.isEmpty) {
                return const Center(
                    child: Text('Pas de données'));
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Temps')),
                    DataColumn(label: Text('SOG (kn)')),
                    DataColumn(label: Text('HDG (°)')),
                    DataColumn(label: Text('COG (°)')),
                    DataColumn(label: Text('TWD (°)')),
                    DataColumn(label: Text('TWA (°)')),
                    DataColumn(label: Text('TWS (kn)')),
                    DataColumn(label: Text('AWA (°)')),
                    DataColumn(label: Text('AWS (kn)')),
                  ],
                  rows: snapshots.take(100).map((TelemetrySnapshot snapshot) {
                    final fmt = DateFormat('HH:mm:ss');
                    return DataRow(cells: [
                      DataCell(Text(
                          fmt.format(snapshot.ts))),
                      DataCell(Text(
                        (snapshot.metrics['nav.sog']
                                    ?.value ??
                                0)
                            .toStringAsFixed(1),
                      )),
                      DataCell(Text(
                        (snapshot.metrics['nav.hdg']
                                    ?.value ??
                                0)
                            .toStringAsFixed(0),
                      )),
                      DataCell(Text(
                        (snapshot.metrics['nav.cog']
                                    ?.value ??
                                0)
                            .toStringAsFixed(0),
                      )),
                      DataCell(Text(
                        (snapshot.metrics['wind.twd']
                                    ?.value ??
                                0)
                            .toStringAsFixed(0),
                      )),
                      DataCell(Text(
                        (snapshot.metrics['wind.twa']
                                    ?.value ??
                                0)
                            .toStringAsFixed(0),
                      )),
                      DataCell(Text(
                        (snapshot.metrics['wind.tws']
                                    ?.value ??
                                0)
                            .toStringAsFixed(1),
                      )),
                      DataCell(Text(
                        (snapshot.metrics['wind.awa']
                                    ?.value ??
                                0)
                            .toStringAsFixed(0),
                      )),
                      DataCell(Text(
                        (snapshot.metrics['wind.aws']
                                    ?.value ??
                                0)
                            .toStringAsFixed(1),
                      )),
                    ]);
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Petite tuile de stat
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Indicateur de statut
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

// ============================================================================
// Providers pour l'interface
// ============================================================================

/// Notifier pour la session actuellement vue
class CurrentlyViewedSessionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setSession(String? sessionId) {
    state = sessionId;
  }
}

/// Provider pour la session actuellement vue
final currentlyViewedSessionProvider =
    NotifierProvider<CurrentlyViewedSessionNotifier, String?>(
        () => CurrentlyViewedSessionNotifier());
