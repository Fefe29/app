import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';

class AdvancedAnalysisPage extends ConsumerStatefulWidget {
  const AdvancedAnalysisPage({super.key});

  @override
  ConsumerState<AdvancedAnalysisPage> createState() => _AdvancedAnalysisPageState();
}

class _AdvancedAnalysisPageState extends ConsumerState<AdvancedAnalysisPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analyse Avancée')),
      body: Column(
        children: [
          _RecordingControlPanel(recordingState: recordingState),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 250,
                  child: _SessionSelector(
                    onSessionSelected: (sessionId) {
                      setState(() => _selectedSessionId = sessionId);
                    },
                    currentlySelected: _selectedSessionId,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _selectedSessionId == null
                      ? const Center(child: Text('Sélectionnez une session'))
                      : Column(
                          children: [
                            TabBar(
                              controller: _tabController,
                              tabs: const [
                                Tab(text: 'Tableau'),
                                Tab(text: 'Polaires'),
                                Tab(text: 'Graphes'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _DataTableTab(sessionId: _selectedSessionId!),
                                  _PolairesTab(sessionId: _selectedSessionId!),
                                  _GraphesTab(sessionId: _selectedSessionId!),
                                ],
                              ),
                            ),
                          ],
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

class _RecordingControlPanel extends ConsumerWidget {
  final RecorderState recordingState;

  const _RecordingControlPanel({required this.recordingState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: recordingState == RecorderState.recording
                ? () => ref.read(recordingStateProvider.notifier).stopRecording()
                : () => ref.read(recordingStateProvider.notifier).startRecording('session_${DateTime.now().millisecondsSinceEpoch}'),
            icon: Icon(recordingState == RecorderState.recording ? Icons.stop : Icons.record_voice_over),
            label: Text(recordingState == RecorderState.recording ? 'Arrêter' : 'Démarrer'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: recordingState == RecorderState.recording
                ? () => ref.read(recordingStateProvider.notifier).pauseRecording()
                : null,
            icon: Icon(recordingState == RecorderState.paused ? Icons.play_arrow : Icons.pause),
            label: Text(recordingState == RecorderState.paused ? 'Reprendre' : 'Pause'),
          ),
          const SizedBox(width: 12),
          _StatusIndicator(state: recordingState),
          const Spacer(),
          Consumer(
            builder: (context, ref, _) {
              final sessionsAsync = ref.watch(sessionsListProvider);
              return sessionsAsync.when(
                loading: () => const Text('Chargement...'),
                error: (err, st) => Text('Erreur: $err'),
                data: (sessions) => Text('${sessions.length} sessions'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SessionSelector extends ConsumerWidget {
  final Function(String) onSessionSelected;
  final String? currentlySelected;

  const _SessionSelector({
    required this.onSessionSelected,
    this.currentlySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsListProvider);

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Erreur: $err')),
      data: (sessions) {
        if (sessions.isEmpty) return const Center(child: Text('Aucune session'));
        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, idx) {
            final session = sessions[idx];
            final isSelected = session.sessionId == currentlySelected;
            return ListTile(
              selected: isSelected,
              selectedTileColor: Colors.blue[50],
              title: Text(session.sessionId),
              subtitle: Text('${session.snapshotCount} mesures'),
              onTap: () => onSessionSelected(session.sessionId),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Exporter CSV'),
                    onTap: () async {
                      try {
                        await ref.read(sessionManagementProvider).exportSession(
                          sessionId: session.sessionId,
                          format: 'csv',
                          outputPath: '/tmp/export_${session.sessionId}.csv',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Export CSV: $e')),
                          );
                        }
                      }
                    },
                  ),
                  PopupMenuItem(
                    child: const Text('Supprimer'),
                    onTap: () => _showDeleteDialog(context, ref, session.sessionId),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer?'),
        content: Text('Supprimer $sessionId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(sessionManagementProvider).deleteSession(sessionId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _DataTableTab extends ConsumerWidget {
  final String sessionId;

  const _DataTableTab({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionDataAsync = ref.watch(sessionDataProvider(sessionId));

    return sessionDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Erreur: $err')),
      data: (snapshots) {
        if (snapshots.isEmpty) return const Center(child: Text('Aucune donnée'));
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('Temps')),
              DataColumn(label: Text('SOG')),
              DataColumn(label: Text('HDG')),
              DataColumn(label: Text('TWS')),
              DataColumn(label: Text('TWD')),
            ],
            rows: snapshots.take(100).map((snapshot) {
              final fmt = DateFormat('HH:mm:ss');
              return DataRow(
                cells: [
                  DataCell(Text(fmt.format(snapshot.ts))),
                  DataCell(Text((snapshot.metrics['nav.sog']?.value ?? 0).toStringAsFixed(1))),
                  DataCell(Text((snapshot.metrics['nav.hdg']?.value ?? 0).toStringAsFixed(0))),
                  DataCell(Text((snapshot.metrics['wind.tws']?.value ?? 0).toStringAsFixed(1))),
                  DataCell(Text((snapshot.metrics['wind.twd']?.value ?? 0).toStringAsFixed(0))),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _PolairesTab extends ConsumerWidget {
  final String sessionId;

  const _PolairesTab({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('Graphique Polaire'),
          const SizedBox(height: 8),
          const Text('Phase 2', style: TextStyle(color: Colors.orange, fontSize: 12)),
        ],
      ),
    );
  }
}

class _GraphesTab extends ConsumerWidget {
  final String sessionId;

  const _GraphesTab({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('Graphes de Performance'),
          const SizedBox(height: 8),
          const Text('Phase 2', style: TextStyle(color: Colors.orange, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final RecorderState state;

  const _StatusIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (state) {
      case RecorderState.idle:
        color = Colors.grey;
      case RecorderState.recording:
        color = Colors.red;
      case RecorderState.paused:
        color = Colors.orange;
      case RecorderState.error:
        color = Colors.red[900] ?? Colors.red;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
