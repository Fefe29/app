// ------------------------------
// File: lib/features/charts/charts_page.dart
// ------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers.dart';


class ChartsPage extends ConsumerWidget {
const ChartsPage({super.key});
@override
Widget build(BuildContext context, WidgetRef ref) {
final stream = ref.watch(snapshotStreamProvider);
return stream.when(
loading: () => const Center(child: CircularProgressIndicator()),
error: (e, _) => Center(child: Text('Error: $e')),
data: (_) => const _TimeSeries(),
);
}
}


class _TimeSeries extends StatefulWidget {
const _TimeSeries();
@override
State<_TimeSeries> createState() => _TimeSeriesState();
}


class _TimeSeriesState extends State<_TimeSeries> {
final List<FlSpot> _sog = [];
final List<FlSpot> _tws = [];


@override
void initState() {
super.initState();
}


@override
Widget build(BuildContext context) {
// Static demo chart; wire to live stream later
return Padding(
padding: const EdgeInsets.all(16),
child: LineChart(
LineChartData(
titlesData: FlTitlesData(show: true),
lineBarsData: [
LineChartBarData(spots: const [FlSpot(0, 5), FlSpot(1, 6.2), FlSpot(2, 5.7), FlSpot(3, 7.1), FlSpot(4, 6.5)]),
LineChartBarData(spots: const [FlSpot(0, 10), FlSpot(1, 12.5), FlSpot(2, 11.8), FlSpot(3, 13.0), FlSpot(4, 12.0)]),
],
),
),
);
}
}