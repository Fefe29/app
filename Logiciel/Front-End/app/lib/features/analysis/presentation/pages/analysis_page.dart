/// Analysis main page with telemetry recording integration.
/// 
/// Architecture simplifiée:
/// - Un seul onglet "Analyse" avec graphiques
/// - Drawer: Menu de sélection des données affichées
/// - Menu d'action (hamburger): Enregistrement et Gestion des sessions
/// - Fenêtres de dialogue pour Enregistrement et Gestion
///
/// See ARCHITECTURE_DOCS.md (section: analysis_page.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/analysis_filters.dart';
import '../widgets/single_wind_metric_chart.dart';
import '../widgets/polar_chart.dart';
import '../widgets/telemetry_widgets.dart';
import '../widgets/analysis_filter_drawer.dart';
import '../widgets/wind_analysis_config.dart';
import '../../domain/services/wind_history_service.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

final polarsJ80Provider = FutureProvider<_PolarsJ80Data>((ref) async {
  final raw = await rootBundle.loadString('assets/polars/j80.csv');
  final lines = LineSplitter.split(raw).toList();
  // En-tête
  final header = lines.first.split(';');
  final windForces = header.skip(1).map((e) => int.tryParse(e) ?? 0).toList();
  final List<double> angles = [];
  final Map<int, List<double>> polaires = { for (var f in windForces) f: [] };
  for (var line in lines.skip(1)) {
    final parts = line.split(';');
    final angle = double.tryParse(parts[0]) ?? 0.0;
    angles.add(angle);
    for (int i = 0; i < windForces.length; i++) {
      final v = double.tryParse(parts[i+1]) ?? 0.0;
      polaires[windForces[i]]?.add(v);
    }
  }
  return _PolarsJ80Data(polaires: polaires, angles: angles, windForces: windForces);
});


class _PolarsJ80Data {
  final Map<int, List<double>> polaires;
  final List<double> angles;
  final List<int> windForces;
  _PolarsJ80Data({required this.polaires, required this.angles, required this.windForces});
}

class AnalysisPage extends StatelessWidget {
  const AnalysisPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AnalysisFilterDrawer(),
      body: const _AnalysisTab(),
    );
  }
}

// ============================================================================
// ONGLET 1: ANALYSIS (Graphiques + Stats clés)
// ============================================================================

class _AnalysisTab extends ConsumerStatefulWidget {
  const _AnalysisTab();

  @override
  ConsumerState<_AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends ConsumerState<_AnalysisTab> {
  late ValueNotifier<int?> selectedWindForce;

  @override
  void initState() {
    super.initState();
    selectedWindForce = ValueNotifier<int?>(null);
  }

  @override
  void dispose() {
    selectedWindForce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polarsAsync = ref.watch(polarsJ80Provider);
    final filters = ref.watch(analysisFiltersProvider);
    final sessionsAsync = ref.watch(sessionsListProvider);
    final selectedSessionId = ref.watch(selectedSessionProvider);
    final recordingState = ref.watch(recordingStateProvider);
    final recorder = ref.watch(telemetryRecorderProvider);

    // Déterminer s'il y a un enregistrement en cours
    final isRecording = recordingState == RecorderState.recording;
    final currentSessionId = isRecording ? recorder.currentSessionId : null;

    return Stack(
      children: [
        // Main content (ListView)
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          shrinkWrap: false,
          children: [
            // Configuration de l'analyse des tendances
            const WindAnalysisConfig(),
            
            const SizedBox(height: 24),
            
            // Statistiques - 3 cas possibles:
            // 1. En cours d'enregistrement → Stats live de la session en cours
            // 2. Session sélectionnée → Stats finales de la session
            // 3. Sinon → Message "Sélectionnez une session"
            
            if (currentSessionId != null)
              // CAS 1: Enregistrement en cours
              SessionStatsWidget(
                sessionId: currentSessionId,
                isLive: true,
              )
            else if (selectedSessionId != null)
              // CAS 2: Session sélectionnée
              sessionsAsync.when(
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, st) => SizedBox(
                  height: 200,
                  child: Center(child: Text('Erreur chargement stats')),
                ),
                data: (sessions) {
                  // Chercher la session sélectionnée
                  final selectedSession = sessions.firstWhere(
                    (s) => s.sessionId == selectedSessionId,
                    orElse: () => sessions.first,
                  );
                  return SessionStatsWidget(
                    sessionId: selectedSession.sessionId,
                    isLive: false,
                  );
                },
              )
            else
              // CAS 3: Temps réel sans session - afficher message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 Statistiques',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sélectionnez une session pour voir ses statistiques détaillées.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // Graphiques du vent
            if (filters.twd) const SingleWindMetricChart(metricType: WindMetricType.twd),
            if (filters.twa) const SingleWindMetricChart(metricType: WindMetricType.twa),
            if (filters.tws) const SingleWindMetricChart(metricType: WindMetricType.tws),
            if (filters.boatSpeed) _plotCard('Vitesse du bateau', 'Vitesse au fil du temps'),
            if (filters.polars) _buildPolarsCard(polarsAsync),
            
            // Help card si aucune métrique sélectionnée
            if (!filters.twd && !filters.tws && !filters.twa && !filters.boatSpeed && !filters.polars)
              _buildHelpCard(),
          ],
        ),
        
        // Floating bubble button to open drawer (left) - always on top
        Positioned(
          top: 24,
          left: 8,
          child: Material(
            color: Colors.transparent,
            elevation: 4,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Ink(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                width: 48,
                height: 48,
                child: const Icon(Icons.menu, color: Colors.black, size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _plotCard(String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 200,
        child: ListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.show_chart),
        ),
      ),
    );
  }

  // Widget optimisé pour éviter les rebuilds inutiles de la carte polaires
  Widget _buildPolarsCard(AsyncValue<_PolarsJ80Data> polarsAsync) {
    return polarsAsync.when(
      loading: () => const Card(
        child: SizedBox(
          height: 400,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        child: SizedBox(
          height: 100,
          child: Center(child: Text('Erreur chargement polaires: $e')),
        ),
      ),
      data: (data) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Polaires J80', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ValueListenableBuilder<int?>(
                  valueListenable: selectedWindForce,
                  builder: (context, value, _) {
                    return Row(
                      children: [
                        DropdownButton<int?>(
                          value: value,
                          hint: const Text('Force de vent'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Toutes')),
                            ...data.windForces.map((f) => DropdownMenuItem<int?>(value: f, child: Text('$f nds'))),
                          ],
                          onChanged: (v) => selectedWindForce.value = v,
                        ),
                        const SizedBox(width: 16),
                        Consumer(
                          builder: (context, ref, _) {
                            final twsAsync = ref.watch(twsHistoryProvider);
                            int currentWindForce = 10;
                            twsAsync.whenData((twsList) {
                              if (data.windForces.isNotEmpty && twsList.isNotEmpty) {
                                final tws = twsList.last.value;
                                currentWindForce = data.windForces.reduce((a, b) => (tws - a).abs() < (tws - b).abs() ? a : b);
                              }
                            });
                            return Text('Force actuelle: $currentWindForce nds', style: const TextStyle(fontSize: 12));
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<int?>(
                  valueListenable: selectedWindForce,
                  builder: (context, value, _) {
                    return Consumer(
                      builder: (context, ref, _) {
                        final twsAsync = ref.watch(twsHistoryProvider);
                        int currentWindForce = 10;
                        twsAsync.whenData((twsList) {
                          if (data.windForces.isNotEmpty && twsList.isNotEmpty) {
                            final tws = twsList.last.value;
                            currentWindForce = data.windForces.reduce((a, b) => (tws - a).abs() < (tws - b).abs() ? a : b);
                          }
                        });
                        return PolarChart(
                          polaires: data.polaires,
                          angles: data.angles,
                          selectedWindForce: value,
                          currentWindForce: currentWindForce,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'Aucune donnée sélectionnée',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Utilisez le menu latéral pour choisir les métriques',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
