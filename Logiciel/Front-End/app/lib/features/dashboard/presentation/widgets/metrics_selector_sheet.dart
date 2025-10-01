import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/providers.dart';

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
                    for (final key in allMetricKeys)
                      CheckboxListTile(
                        value: selected.contains(key),
                        onChanged: (v) => ref
                            .read(selectedMetricsProvider.notifier)
                            .toggle(key, v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(key),
                      ),
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
