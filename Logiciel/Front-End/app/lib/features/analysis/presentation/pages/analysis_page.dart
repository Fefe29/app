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
import '../../domain/services/wind_history_service.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

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

class _AnalysisTab extends ConsumerWidget {
  const _AnalysisTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final polarsAsync = ref.watch(polarsJ80Provider);
    final selectedWindForce = ValueNotifier<int?>(null);
    final filters = ref.watch(analysisFiltersProvider);
    final sessionsAsync = ref.watch(sessionsListProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Graphiques du vent
        if (filters.twd) const SingleWindMetricChart(metricType: WindMetricType.twd),
        if (filters.twa) const SingleWindMetricChart(metricType: WindMetricType.twa),
        if (filters.tws) const SingleWindMetricChart(metricType: WindMetricType.tws),
        if (filters.boatSpeed) _plotCard('Vitesse du bateau', 'Vitesse au fil du temps'),
        if (filters.polars)
          polarsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erreur chargement polaires: $e'),
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
          ),
        
        // Separator + Stats clés de la dernière session
        if (!filters.twd && !filters.tws && !filters.twa && !filters.boatSpeed && !filters.polars)
          _buildHelpCard()
        else ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          sessionsAsync.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, st) => SizedBox(
              height: 200,
              child: Center(child: Text('Aucune session')),
            ),
            data: (sessions) {
              if (sessions.isEmpty) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: Text('Aucune session enregistrée')),
                );
              }
              final latestSession = sessions.first;
              return SessionStatsWidget(sessionId: latestSession.sessionId);
            },
          ),
        ],
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
