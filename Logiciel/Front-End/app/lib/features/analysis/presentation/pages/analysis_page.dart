/// Analysis main page.
/// See ARCHITECTURE_DOCS.md (section: analysis_page.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/analysis_filters.dart';
import '../widgets/single_wind_metric_chart.dart';
import '../widgets/wind_analysis_config.dart';
import '../widgets/polar_chart.dart';
import '../../domain/services/wind_history_service.dart';
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
    final selectedWindForce = ValueNotifier<int?>(null);
    return Consumer(
      builder: (context, ref, _) {
        final polarsAsync = ref.watch(polarsJ80Provider);
        return Stack(
          children: [
            // Main content (no info bar)
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final f = ref.watch(analysisFiltersProvider);
                    return Column(
                      children: [
                        if (f.twd) const SingleWindMetricChart(metricType: WindMetricType.twd),
                        if (f.twa) const SingleWindMetricChart(metricType: WindMetricType.twa),
                        if (f.tws) const SingleWindMetricChart(metricType: WindMetricType.tws),
                        if (f.boatSpeed) _plotCard('Vitesse du bateau', 'Vitesse au fil du temps'),
                        if (f.polars)
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
                                              // Affichage force actuelle dans un Consumer local
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
                                      // PolarChart isolé dans un Consumer pour éviter le rebuild global
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
                        if (!f.twd && !f.tws && !f.twa && !f.boatSpeed && !f.polars)
                          _buildHelpCard(),
                      ],
                    );
                  },
                ),
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
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.tune, color: Colors.black, size: 20),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

  Widget _buildAnalysisHeader(BuildContext context, {bool showDrawerButton = true}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.analytics, color: Colors.blue, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analyse du Vent en Temps Réel',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text(
                    'Chaque graphique affiche l\'historique d\'une métrique spécifique',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            // Plus de bouton drawer ici
          ],
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
            Builder(
              builder: (BuildContext context) => Text(
                'Aucune donnée sélectionnée',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Utilisez le menu latéral pour choisir les métriques de vent que vous souhaitez analyser. Chaque métrique aura son propre graphique dédié.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildMetricChip('TWD', 'Direction', Colors.blue, Icons.explore),
                _buildMetricChip('TWA', 'Angle', Colors.red, Icons.navigation),
                _buildMetricChip('TWS', 'Vitesse', Colors.green, Icons.air),
              ],
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (BuildContext context) => FilledButton.icon(
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
                icon: const Icon(Icons.tune),
                label: const Text('Sélectionner les données'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String title, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
