// ------------------------------
// File: lib/features/dashboard/widgets/metric_tile.dart
// ------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';


class MetricTile extends ConsumerWidget {
final String metricKey;
const MetricTile({super.key, required this.metricKey});


@override
Widget build(BuildContext context, WidgetRef ref) {
final asyncM = ref.watch(metricProvider(metricKey));
final cs = Theme.of(context).colorScheme;
return Card(
elevation: 0,
color: cs.surface,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
child: Padding(
padding: const EdgeInsets.all(16),
child: asyncM.when(
loading: () => const Center(child: CircularProgressIndicator()),
error: (e, _) => Center(child: Text('Err: $e')),
data: (m) => Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(metricKey, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
Align(
alignment: Alignment.centerLeft,
child: FittedBox(
fit: BoxFit.scaleDown,
child: Text(
m.value.toStringAsFixed(1),
style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
),
),
),
Text(m.unit.symbol, style: TextStyle(color: cs.onSurfaceVariant)),
],
),
),
}