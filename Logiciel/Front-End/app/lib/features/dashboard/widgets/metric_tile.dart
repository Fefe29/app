// ------------------------------
// File: lib/features/dashboard/widgets/metric_tile.dart
// ------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';

class MetricTile extends StatelessWidget {
  final String metricKey;
  const MetricTile({Key? key, required this.metricKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer(
      builder: (context, ref, _) {
        final asyncM = ref.watch(metricProvider(metricKey));

        // Affiche toujours quelque chose (évite le flicker “loader → data → loader”)
        final hasValue = asyncM.hasValue;
        final valueText = hasValue ? _fmt(asyncM.value!.value) : '--';
        final unitText  = hasValue ? asyncM.value!.unit.symbol : '';

        return RepaintBoundary(
          child: Card(
            elevation: 0,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    metricKey,
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        valueText,
                        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Text(unitText, style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmt(num v) => v is int ? '$v' : (v as double).toStringAsFixed(1);
}
