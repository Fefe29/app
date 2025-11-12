/// Exemple d'utilisation des données NMEA dans un widget
/// 
/// Ce fichier montre comment utiliser les données de télémétrie
/// (NMEA réel ou simulation) dans vos widgets.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/common/providers/app_providers.dart';

/// Widget exemple: Affichage des données NMEA en temps réel
class NmeaDataDisplayExample extends ConsumerWidget {
  const NmeaDataDisplayExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Regarder les données de vent (fusionné fake/real)
    final windSample = ref.watch(windSampleProvider);

    // Regarder une métrique spécifique (true wind speed)
    final twsAsync = ref.watch(metricProvider('wind.tws'));

    // Regarder une autre métrique (speed over ground)
    final sogAsync = ref.watch(metricProvider('nav.sog'));

    // Regarder un snapshot complet
    final snapshotAsync = ref.watch(snapshotStreamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // ====== Section 1: Vent (Utilise WindSample) ======
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Données de Vent (WindSample)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDataRow('Direction du Vent', '${windSample.directionDeg.toStringAsFixed(1)}°'),
                  _buildDataRow('Vitesse du Vent', '${windSample.speed.toStringAsFixed(1)} kt'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ====== Section 2: Métrique Individuelle (TWS) ======
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'True Wind Speed (Métrique Individuelle)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  twsAsync.when(
                    data: (measurement) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDataRow('Valeur', '${measurement.value.toStringAsFixed(1)} ${measurement.unit.symbol}'),
                        _buildDataRow('Timestamp', measurement.ts.toIso8601String()),
                        _buildDataRow('Source', 'NMEA ou Simulation'),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (err, st) => Text('Erreur: $err'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ====== Section 3: Plusieurs Métriques (SOG) ======
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speed Over Ground (SOG)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  sogAsync.when(
                    data: (measurement) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDataRow('Valeur', '${measurement.value.toStringAsFixed(1)} ${measurement.unit.symbol}'),
                        _buildDataRow('Qualité', measurement.value > 0 ? '✅' : '⚠️'),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (err, st) => Text('Erreur: $err'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ====== Section 4: Snapshot Complet ======
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Snapshot Complet (Toutes Métriques)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  snapshotAsync.when(
                    data: (snapshot) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDataRow('Nombre de métriques', '${snapshot.metrics.length}'),
                        _buildDataRow('Timestamp', snapshot.ts.toIso8601String()),
                        if (snapshot.tags.containsKey('source'))
                          _buildDataRow('Source', snapshot.tags['source'].toString()),
                        const SizedBox(height: 12),
                        const Text('Métriques disponibles:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: snapshot.metrics.length,
                            itemBuilder: (context, index) {
                              final entry = snapshot.metrics.entries.elementAt(index);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                    ),
                                    Text(
                                      '${entry.value.value.toStringAsFixed(2)} ${entry.value.unit.symbol}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (err, st) => Text('Erreur: $err'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Exemple 2: Widget minimaliste pour le vent
class WindIndicator extends ConsumerWidget {
  const WindIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windSample = ref.watch(windSampleProvider);

    return Column(
      children: [
        Text(
          '${windSample.speed.toStringAsFixed(1)} kt',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          '${windSample.directionDeg.toStringAsFixed(0)}°',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }
}

/// Exemple 3: Compass/Rose des vents simplifié
class WindCompass extends ConsumerWidget {
  const WindCompass({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windSample = ref.watch(windSampleProvider);
    final angle = windSample.directionDeg;

    return Center(
      child: Transform.rotate(
        angle: (angle * 3.14159) / 180,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.north, size: 30, color: Colors.red),
                Text(
                  '${angle.toStringAsFixed(0)}°',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Exemple 4: Tableau de bord avec plusieurs métriques
class TelemetryDashboard extends ConsumerWidget {
  const TelemetryDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(snapshotStreamProvider);

    return snapshotAsync.when(
      data: (snapshot) => GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        padding: const EdgeInsets.all(12),
        children: [
          _buildMetricCard(
            'TWS',
            snapshot.metrics['wind.tws']?.value.toStringAsFixed(1) ?? '--',
            'kt',
          ),
          _buildMetricCard(
            'TWD',
            snapshot.metrics['wind.twd']?.value.toStringAsFixed(0) ?? '--',
            '°',
          ),
          _buildMetricCard(
            'SOG',
            snapshot.metrics['nav.sog']?.value.toStringAsFixed(1) ?? '--',
            'kt',
          ),
          _buildMetricCard(
            'COG',
            snapshot.metrics['nav.cog']?.value.toStringAsFixed(0) ?? '--',
            '°',
          ),
          _buildMetricCard(
            'Depth',
            snapshot.metrics['env.depth']?.value.toStringAsFixed(1) ?? '--',
            'm',
          ),
          _buildMetricCard(
            'Temp',
            snapshot.metrics['env.waterTemp']?.value.toStringAsFixed(1) ?? '--',
            '°C',
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Erreur: $err')),
    );
  }

  Widget _buildMetricCard(String label, String value, String unit) {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('$value $unit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// Exemple d'intégration dans une screen
class NmeaExampleScreen extends ConsumerWidget {
  const NmeaExampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Données NMEA - Exemples'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Affichage Complet'),
              Tab(text: 'Tableau Bord'),
              Tab(text: 'Compass'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            NmeaDataDisplayExample(),
            TelemetryDashboard(),
            WindCompass(),
          ],
        ),
      ),
    );
  }
}
