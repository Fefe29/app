// ------------------------------
// File: lib/features/dashboard/dashboard_page.dart
// ------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import 'widgets/metric_tile.dart';


class DashboardPage extends ConsumerWidget {
const DashboardPage({super.key});


static const defaultKeys = [
'nav.sog','nav.cog','wind.twa','wind.tws','wind.awa','wind.aws','nav.hdg','env.depth','env.waterTemp'
];


@override
Widget build(BuildContext context, WidgetRef ref) {
// We don't need the snapshot content here; just ensure the bus is alive
ref.watch(snapshotStreamProvider);
final cols = MediaQuery.of(context).size.width > 800 ? 4 : 2;
return Padding(
padding: const EdgeInsets.all(12),
child: GridView.builder(
itemCount: defaultKeys.length,
gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12,
),
itemBuilder: (_, i) => MetricTile(metricKey: defaultKeys[i]),
),
);
}
}