/// Dashboard page layout.
/// See ARCHITECTURE_DOCS.md (section: dashboard_page.dart).
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/providers.dart';
import '../widgets/metric_tile.dart';
import '../widgets/metrics_selector_sheet.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  int _columnsForWidth(double w, int n) {
    final minTile = 160.0;
    final byWidth = max(1, (w / minTile).floor());
    final square  = max(1, (sqrt(n)).ceil());
    final base = w > 800 ? 4 : 2;
    return max(1, min(min(base, byWidth), square));
  }

  Future<void> _openSelector(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MetricsSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ On garde le flux en vie sans rebuild toute la page
    ref.listen(snapshotStreamProvider, (_, __) {});

    final asyncSel = ref.watch(selectedMetricsProvider);

    return asyncSel.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (selectedKeys) {
        final keys = selectedKeys.toList();
        return Stack(
          children: [
            LayoutBuilder(
              builder: (ctx, c) {
                final cols = _columnsForWidth(c.maxWidth, keys.length);
                if (keys.isEmpty) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => _openSelector(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('Choisir des données'),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    itemCount: keys.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemBuilder: (_, i) => MetricTile(
                      key: ValueKey(keys[i]),   // identité stable => moins de clignotements
                      metricKey: keys[i],
                    ),
                  ),
                );
              },
            ),
            // Bouton de sélection des métriques en haut à gauche
            Positioned(
              left: 10,
              top: 10 + MediaQuery.of(context).padding.top,
              child: Material(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _openSelector(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    // Icône à trois barres simples (menu / hamburger)
                    child: Icon(Icons.menu, size: 20),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
