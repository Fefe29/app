/// Widget de graphique individuel pour une métrique de vent spécifique
/// Affiche un seul type de données (TWD, TWA ou TWS) sur un graphique dédié
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/services/wind_history_service.dart';

enum WindMetricType { twd, twa, tws }

/// Widget de graphique pour une métrique de vent individuelle
class SingleWindMetricChart extends ConsumerWidget {
  const SingleWindMetricChart({
    super.key,
    required this.metricType,
  });

  final WindMetricType metricType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = _getHistoryProvider(metricType).call(ref);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, ref),
            const SizedBox(height: 16),
            
            // Graphique principal  
            SizedBox(
              height: 250,
              child: historyAsync.when(
                data: (data) => _buildChart(context, data),
                loading: () => _buildLoadingChart(),
                error: (error, stack) => _buildErrorChart('Erreur: $error'),
              ),
            ),
            
            const SizedBox(height: 8),
            _buildDataSummary(historyAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final config = _getMetricConfig(metricType);
    
    return Row(
      children: [
        Icon(config.icon, color: config.color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                config.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.read(windHistoryServiceProvider).clearHistory();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Historique ${config.title} effacé')),
            );
          },
          tooltip: 'Effacer l\'historique',
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, List<HistoryDataPoint> data) {
    if (data.isEmpty) {
      return _buildEmptyChart();
    }

    // Trouver la plage de temps
    final startTime = data.first.timestamp;
    final endTime = data.last.timestamp;
    final duration = endTime.difference(startTime).inMilliseconds.toDouble();
    
    if (duration <= 0) return _buildEmptyChart();

    final config = _getMetricConfig(metricType);
    
    // Calculer les valeurs min/max pour l'axe Y
    final values = data.map((p) => p.value).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    
    // Ajouter une marge de 10% autour des valeurs
    final range = maxValue - minValue;
    final margin = range * 0.1;
    final yMin = (minValue - margin).clamp(config.minY, config.maxY);
    final yMax = (maxValue + margin).clamp(config.minY, config.maxY);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          getDrawingVerticalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.3),
            strokeWidth: 0.5,
          ),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.3),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final time = DateTime.fromMillisecondsSinceEpoch(
                  startTime.millisecondsSinceEpoch + value.toInt(),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('HH:mm:ss').format(time),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(0)}${config.unit}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.5)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data.map((point) {
              final x = point.timestamp.difference(startTime).inMilliseconds.toDouble();
              return FlSpot(x, point.value);
            }).toList(),
            isCurved: true,
            color: config.color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: data.length <= 50, // Afficher les points seulement si peu de données
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 2,
                  color: config.color,
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: config.color.withOpacity(0.1),
            ),
          ),
        ],
        minX: 0,
        maxX: duration,
        minY: yMin,
        maxY: yMax,
      ),
    );
  }

  Widget _buildLoadingChart() {
    final config = _getMetricConfig(metricType);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: config.color),
          const SizedBox(height: 16),
          Text('Collecte des données ${config.title}...'),
        ],
      ),
    );
  }

  Widget _buildErrorChart(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Erreur: $error'),
        ],
      ),
    );
  }

  Widget _buildEmptyChart() {
    final config = _getMetricConfig(metricType);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(config.icon, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text('En attente de données ${config.title}...'),
          const SizedBox(height: 8),
          const Text(
            'Les données apparaîtront automatiquement.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDataSummary(AsyncValue<List<HistoryDataPoint>> historyAsync) {
    final count = historyAsync.whenOrNull(data: (data) => data.length) ?? 0;
    final lastValue = historyAsync.whenOrNull(data: (data) => data.isNotEmpty ? data.last.value : null);
    final config = _getMetricConfig(metricType);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: config.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Dernière valeur', 
            lastValue != null ? '${lastValue.toStringAsFixed(1)}${config.unit}' : '--'),
          _buildSummaryItem('Points collectés', '$count'),
          _buildSummaryItem('Durée', 
            count > 1 ? '${(count / 60).toStringAsFixed(1)}min' : '--'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  // Configuration pour chaque type de métrique
  _MetricConfig _getMetricConfig(WindMetricType type) {
    switch (type) {
      case WindMetricType.twd:
        return _MetricConfig(
          title: 'Direction du Vent (TWD)',
          subtitle: 'Direction absolue du vent vraie',
          icon: Icons.explore,
          color: Colors.blue,
          unit: '°',
          minY: 0,
          maxY: 360,
        );
      case WindMetricType.twa:
        return _MetricConfig(
          title: 'Angle au Vent (TWA)',
          subtitle: 'Angle relatif du vent par rapport au bateau',
          icon: Icons.navigation,
          color: Colors.red,
          unit: '°',
          minY: -180,
          maxY: 180,
        );
      case WindMetricType.tws:
        return _MetricConfig(
          title: 'Vitesse du Vent (TWS)',
          subtitle: 'Vitesse du vent vraie',
          icon: Icons.air,
          color: Colors.green,
          unit: 'nds',
          minY: 0,
          maxY: 50,
        );
    }
  }

  // Obtenir le provider approprié selon le type
  AsyncValue<List<HistoryDataPoint>> Function(WidgetRef) _getHistoryProvider(WindMetricType type) {
    switch (type) {
      case WindMetricType.twd:
        return (ref) => ref.watch(twdHistoryProvider);
      case WindMetricType.twa:
        return (ref) => ref.watch(twaHistoryProvider);
      case WindMetricType.tws:
        return (ref) => ref.watch(twsHistoryProvider);
    }
  }
}

class _MetricConfig {
  const _MetricConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.unit,
    required this.minY,
    required this.maxY,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String unit;
  final double minY;
  final double maxY;
}