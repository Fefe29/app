/// Widget d'affichage des graphiques d'historique du vent
/// Utilise fl_chart pour afficher TWD, TWA et TWS dans le temps
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/services/wind_history_service.dart';

/// Widget de graphique pour l'historique du vent
class WindHistoryChart extends ConsumerWidget {
  const WindHistoryChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final twdHistoryAsync = ref.watch(twdHistoryProvider);
    final twaHistoryAsync = ref.watch(twaHistoryProvider);
    final twsHistoryAsync = ref.watch(twsHistoryProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.air, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Historique du Vent',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref.read(windHistoryServiceProvider).clearHistory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Historique effacé')),
                    );
                  },
                  tooltip: 'Effacer l\'historique',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Légende
            _buildLegend(),
            const SizedBox(height: 16),
            
            // Graphique principal  
            SizedBox(
              height: 300,
              child: twdHistoryAsync.when(
                data: (twdData) => twaHistoryAsync.when(
                  data: (twaData) => twsHistoryAsync.when(
                    data: (twsData) => _buildChart(
                      context,
                      twdData: twdData,
                      twaData: twaData, 
                      twsData: twsData,
                    ),
                    loading: () => _buildLoadingChart(),
                    error: (error, stack) => _buildErrorChart('Erreur TWS: $error'),
                  ),
                  loading: () => _buildLoadingChart(),
                  error: (error, stack) => _buildErrorChart('Erreur TWA: $error'),
                ),
                loading: () => _buildLoadingChart(),
                error: (error, stack) => _buildErrorChart('Erreur TWD: $error'),
              ),
            ),
            
            const SizedBox(height: 8),
            _buildDataSummary(twdHistoryAsync, twaHistoryAsync, twsHistoryAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLegendItem('TWD', Colors.blue, 'Direction du vent (°)'),
        _buildLegendItem('TWA', Colors.red, 'Angle au vent (°)'),
        _buildLegendItem('TWS', Colors.green, 'Vitesse du vent (nds)'),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, String description) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 3,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Text(
          description,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildChart(
    BuildContext context, {
    required List<HistoryDataPoint> twdData,
    required List<HistoryDataPoint> twaData,
    required List<HistoryDataPoint> twsData,
  }) {
    if (twdData.isEmpty && twaData.isEmpty && twsData.isEmpty) {
      return _buildEmptyChart();
    }

    // Trouver la plage de temps commune
    final allTimes = <DateTime>[];
    allTimes.addAll(twdData.map((p) => p.timestamp));
    allTimes.addAll(twaData.map((p) => p.timestamp));
    allTimes.addAll(twsData.map((p) => p.timestamp));
    
    if (allTimes.isEmpty) return _buildEmptyChart();
    
    allTimes.sort();
    final startTime = allTimes.first;
    final endTime = allTimes.last;
    final duration = endTime.difference(startTime).inMilliseconds.toDouble();
    
    if (duration <= 0) return _buildEmptyChart();

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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
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
          // TWD (Direction du vent)
          if (twdData.isNotEmpty)
            _createLineBarData(
              twdData,
              startTime,
              Colors.blue,
              'TWD',
            ),
          
          // TWA (Angle au vent) 
          if (twaData.isNotEmpty)
            _createLineBarData(
              twaData,
              startTime,
              Colors.red,
              'TWA',
            ),
          
          // TWS (Vitesse du vent) - mise à l'échelle pour l'affichage
          if (twsData.isNotEmpty)
            _createLineBarData(
              twsData.map((p) => HistoryDataPoint(
                timestamp: p.timestamp,
                value: p.value * 10, // Mise à l'échelle pour visibilité
              )).toList(),
              startTime,
              Colors.green,
              'TWS×10',
            ),
        ],
        minX: 0,
        maxX: duration,
        minY: -200, // Pour permettre les angles négatifs TWA
        maxY: 400,  // Pour couvrir TWD (0-360°) et TWS mis à l'échelle
      ),
    );
  }

  LineChartBarData _createLineBarData(
    List<HistoryDataPoint> data,
    DateTime startTime,
    Color color,
    String label,
  ) {
    final spots = data.map((point) {
      final x = point.timestamp.difference(startTime).inMilliseconds.toDouble();
      return FlSpot(x, point.value);
    }).toList();

    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 2,
      isStrokeCapRound: false,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildLoadingChart() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Collecte des données en cours...'),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('En attente de données...'),
          SizedBox(height: 8),
          Text(
            'Les données apparaîtront automatiquement quand le vent sera détecté.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDataSummary(
    AsyncValue<List<HistoryDataPoint>> twdAsync,
    AsyncValue<List<HistoryDataPoint>> twaAsync,
    AsyncValue<List<HistoryDataPoint>> twsAsync,
  ) {
    final twdCount = twdAsync.whenOrNull(data: (data) => data.length) ?? 0;
    final twaCount = twaAsync.whenOrNull(data: (data) => data.length) ?? 0;
    final twsCount = twsAsync.whenOrNull(data: (data) => data.length) ?? 0;
    
    final twdLast = twdAsync.whenOrNull(data: (data) => data.isNotEmpty ? data.last.value : null);
    final twaLast = twaAsync.whenOrNull(data: (data) => data.isNotEmpty ? data.last.value : null);
    final twsLast = twsAsync.whenOrNull(data: (data) => data.isNotEmpty ? data.last.value : null);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('TWD', twdLast, twdCount, '°', Colors.blue),
          _buildSummaryItem('TWA', twaLast, twaCount, '°', Colors.red),
          _buildSummaryItem('TWS', twsLast, twsCount, 'nds', Colors.green),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    double? lastValue,
    int count,
    String unit,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          lastValue != null 
            ? '${lastValue.toStringAsFixed(1)}$unit'
            : '--',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          '$count pts',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}