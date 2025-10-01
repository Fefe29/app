import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/analysis_filters.dart';

class AnalysisPage extends ConsumerWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(analysisFiltersProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (f.tws || f.twa) _plotCard('Wind history', 'TWS & TWA over time'),
        if (f.boatSpeed) _plotCard('Boat speed', 'Speed over time'),
        if (f.polars) _plotCard('Polars', 'Performance curve'),
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
}
