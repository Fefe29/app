/// Metric selection bottom sheet.
/// See ARCHITECTURE_DOCS.md (section: metrics_selector_sheet.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/providers.dart';
import 'package:kornog/features/dashboard/providers/metric_categories.dart';

class MetricsSelectorSheet extends ConsumerWidget {
  const MetricsSelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSel = ref.watch(selectedMetricsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Material(
        color: Theme.of(ctx).colorScheme.surface,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44, height: 5,
              decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            Text('Choisir les données à afficher',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: asyncSel.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
                data: (selected) => ListView(
                  controller: scroll,
                  children: [
                    // Afficher les catégories avec leurs métriques
                    for (final category in metricCategories) ...[
                      // En-tête de catégorie
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          category.name,
                          style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Métriques de la catégorie
                      for (final metric in category.metrics)
                        CheckboxListTile(
                          value: selected.contains(metric.key),
                          onChanged: (v) => ref
                              .read(selectedMetricsProvider.notifier)
                              .toggle(metric.key, v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(metric.label),
                          subtitle: metric.description != null
                              ? Text(
                                  metric.description!,
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                        ),
                      const Divider(height: 16, indent: 16, endIndent: 16),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(selectedMetricsProvider.notifier)
                          .reset(),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Réinitialiser'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.check),
                      label: const Text('Appliquer'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

