import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/analysis/analysis_filters.dart';

class AnalysisFilterDrawer extends ConsumerWidget {
  const AnalysisFilterDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(analysisFiltersProvider);
    final setFilters = ref.read(analysisFiltersProvider.notifier);

    void update(AnalysisFilters next) => setFilters.state = next;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Select plots'),
              subtitle: const Text('Choose data to display'),
            ),
            const Divider(),
            SwitchListTile(
              value: filters.tws,
              onChanged: (v) => update(filters.copyWith(tws: v)),
              title: const Text('True Wind Speed (TWS)'),
            ),
            SwitchListTile(
              value: filters.twa,
              onChanged: (v) => update(filters.copyWith(twa: v)),
              title: const Text('True Wind Angle (TWA)'),
            ),
            SwitchListTile(
              value: filters.boatSpeed,
              onChanged: (v) => update(filters.copyWith(boatSpeed: v)),
              title: const Text('Boat speed'),
            ),
            SwitchListTile(
              value: filters.polars,
              onChanged: (v) => update(filters.copyWith(polars: v)),
              title: const Text('Polars'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Running computations…')),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run computations'),
            ),
          ],
        ),
      ),
    );
  }
}
