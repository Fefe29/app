// lib/features/dashboard/widgets/metric_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';

class MetricTile extends ConsumerStatefulWidget {
  final String metricKey;
  const MetricTile({Key? key, required this.metricKey}) : super(key: key);

  @override
  ConsumerState<MetricTile> createState() => _MetricTileState();
}

class _MetricTileState extends ConsumerState<MetricTile>
    with AutomaticKeepAliveClientMixin {
  String? _lastValue;
  String? _lastUnit;

  @override
  bool get wantKeepAlive => true; // garde la tuile vivante

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final asyncM = ref.watch(metricProvider(widget.metricKey));
    final cs = Theme.of(context).colorScheme;

    if (asyncM.hasValue) {
      final m = asyncM.value!;
      _lastValue = _fmt(m.value);
      _lastUnit  = m.unit.symbol;
    }
    // On affiche la dernière valeur connue (ou '--'), JAMAIS un loader agressif
    final valueText = _lastValue ?? '--';
    final unitText  = _lastUnit ?? '';

    return RepaintBoundary(
      child: Card(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.metricKey,
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
  }

  String _fmt(num v) => v is int ? '$v' : (v as double).toStringAsFixed(1);
}
