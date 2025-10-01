// lib/features/dashboard/widgets/metric_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/providers.dart';

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
  late final String _category = widget.metricKey.contains('.')
      ? widget.metricKey.split('.').first
      : 'misc';
  late final String _name = widget.metricKey.contains('.')
      ? widget.metricKey.split('.').last
      : widget.metricKey;

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

    final catTint = _categoryColor(_category, cs);
    final bgColor = catTint.withOpacity(.18);
    final borderColor = catTint.withOpacity(.55);

    return RepaintBoundary(
      child: Card(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor, width: 1.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Catégorie (type)
                      Text(
                        _category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: cs.onSurface.withOpacity(.72),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Nom de la donnée
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .3,
                          color: cs.onSurface.withOpacity(.85),
                        ),
                      ),
                      const Spacer(),
                      // Valeur + unité (alignées sur la ligne de base via Text.rich)
                      AnimatedOpacity(
                        opacity: valueText == '--' ? 0.6 : 1,
                        duration: const Duration(milliseconds: 250),
                        child: Text.rich(
                          TextSpan(
                            text: valueText,
                            style: const TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.2,
                            ),
                            children: [
                              if (unitText.isNotEmpty)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 6, bottom: 4),
                                    child: Text(
                                      unitText,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurfaceVariant,
                                        letterSpacing: .6,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          softWrap: false,
                          overflow: TextOverflow.fade,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(num v) => v is int ? '$v' : (v as double).toStringAsFixed(1);
}

Color _categoryColor(String cat, ColorScheme cs) {
  switch (cat) {
    case 'nav':
      return cs.primary.withOpacity(.12);
    case 'wind':
      return Colors.teal.withOpacity(.18);
    case 'env':
      return Colors.blueGrey.withOpacity(.16);
    default:
      return cs.secondary.withOpacity(.14);
  }
}

// (Ancienne classe _Badge retirée car design refondu)
