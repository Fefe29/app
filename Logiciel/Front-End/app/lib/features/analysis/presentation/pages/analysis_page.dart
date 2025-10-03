/// Analysis main page.
/// See ARCHITECTURE_DOCS.md (section: analysis_page.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/analysis_filters.dart';
import '../widgets/single_wind_metric_chart.dart';
import '../widgets/wind_analysis_config.dart';

class AnalysisPage extends ConsumerWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(analysisFiltersProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // En-tête avec informations
        if (f.twd || f.tws || f.twa) _buildAnalysisHeader(context),
        
        // Configuration de l'analyse des tendances (visible seulement si TWD/TWA actifs)
        if (f.twd || f.twa) const WindAnalysisConfig(),
        
        // Graphiques individuels pour chaque métrique sélectionnée
        if (f.twd) const SingleWindMetricChart(metricType: WindMetricType.twd),
        if (f.twa) const SingleWindMetricChart(metricType: WindMetricType.twa),
        if (f.tws) const SingleWindMetricChart(metricType: WindMetricType.tws),
        
        // Autres graphiques (placeholder pour l'instant)
        if (f.boatSpeed) _plotCard('Vitesse du bateau', 'Vitesse au fil du temps'),
        if (f.polars) _plotCard('Polaires', 'Courbes de performance'),
        
        // Message d'aide si aucun filtre actif
        if (!f.twd && !f.tws && !f.twa && !f.boatSpeed && !f.polars)
          _buildHelpCard(),
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

  Widget _buildAnalysisHeader(BuildContext context) {
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
            Builder(
              builder: (BuildContext context) => IconButton(
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
                icon: const Icon(Icons.tune),
                tooltip: 'Sélectionner les données à afficher',
              ),
            ),
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
