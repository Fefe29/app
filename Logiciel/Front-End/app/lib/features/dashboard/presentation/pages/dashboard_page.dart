/// Dashboard page layout.
/// See ARCHITECTURE_DOCS.md (section: dashboard_page.dart).
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/providers.dart';
import 'package:kornog/app/app_shell.dart';
import '../widgets/metric_tile.dart';
import '../widgets/metrics_selector_sheet.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  int _columnsForWidth(double w, double h, int n) {
    // En portrait (w < h): 2 colonnes
    // En paysage (w > h): distribution intelligente basée sur le nombre de tuiles
    if (w > h) {
      // Paysage: chercher une distribution équilibrée
      // 1-2: 1 col, 3-4: 2 cols, 5-6: 3 cols, 7+: 4 cols
      int cols;
      if (n <= 2) {
        cols = 1;
      } else if (n <= 4) {
        cols = 2;
      } else if (n <= 6) {
        cols = 3;
      } else {
        cols = 4;
      }
      
      // Vérifier que ça rentre à l'écran (minTile = 120)
      final minTile = 120.0;
      final maxColsByWidth = max(1, (w / minTile).floor());
      return min(cols, maxColsByWidth);
    } else {
      // Portrait: 2 colonnes fixe
      return 2;
    }
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
    final barsVisible = ref.watch(barsVisibilityProvider);

    return asyncSel.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (selectedKeys) {
        final keys = selectedKeys.toList();
        return Stack(
          children: [
            LayoutBuilder(
              builder: (ctx, c) {
                final cols = _columnsForWidth(c.maxWidth, c.maxHeight, keys.length);
                if (keys.isEmpty) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => _openSelector(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('Choisir des données'),
                    ),
                  );
                }
                // On calcule la grille de manière à ce que toutes les tuiles rentrent
                const padding = 1.0;
                const spacing = 1.0;
                final contentWidth = max(0.0, c.maxWidth - 2 * padding);
                final contentHeight = max(0.0, c.maxHeight - 2 * padding);
                final rows = (keys.length + cols - 1) ~/ cols; // ceil
                final tileWidth = cols > 0 ? (contentWidth - (cols - 1) * spacing) / cols : contentWidth;
                final tileHeight = rows > 0 ? (contentHeight - (rows - 1) * spacing) / rows : contentHeight;
                final childAspectRatio = tileWidth > 0 && tileHeight > 0 ? tileWidth / tileHeight : 1.0;

                return Padding(
                  padding: const EdgeInsets.all(padding),
                  child: SizedBox(
                    height: c.maxHeight - 2 * padding,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: keys.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (_, i) => MetricTile(
                        key: ValueKey(keys[i]), // identité stable => moins de clignotements
                        metricKey: keys[i],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Bouton de sélection des métriques en haut à gauche
            // Masqué quand les barres sont cachées
            if (barsVisible)
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
