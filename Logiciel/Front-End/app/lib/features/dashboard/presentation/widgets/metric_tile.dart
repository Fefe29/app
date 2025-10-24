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
  double? _lastNumeric; // pour filtrer les micro-variations et éviter les rebuilds visibles
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
      final v = m.value.toDouble();
      // Seuil: on ignore les variations très petites (< 0.02) pour réduire le clignotement
      if (_lastNumeric == null || (v - (_lastNumeric ?? v)).abs() > 0.02) {
        _lastNumeric = v;
        _lastValue = _fmt(v);
      }
      _lastUnit = m.unit.symbol;
    }
    // On affiche la dernière valeur connue (ou '--'), JAMAIS un loader agressif
    final valueText = _lastValue ?? '--';
    final unitText  = _lastUnit ?? '';

  // Fond selon le thème : noir en mode nuit, gris clair sinon
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bgColor = isDark ? Colors.black : Colors.grey[200]!;
  final borderColor = isDark ? Colors.grey[800]! : Colors.grey[400]!;

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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Catégorie (type) + nom regroupés
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _category.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: cs.onSurface.withOpacity(.80),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .4,
                          color: cs.onSurface.withOpacity(.85),
                        ),
                      ),
                      // Valeur centrée
                      Expanded(
                        child: Center(
                          child: Opacity(
                            opacity: valueText == '--' ? 0.55 : 1,
                            child: _StableValue(
                              value: valueText,
                              unit: unitText,
                              colorScheme: cs,
                            ),
                          ),
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
  // Désormais inutilisé, mais conservé pour compatibilité éventuelle
  return Colors.grey[200]!;
}

// (Ancienne classe _Badge retirée car design refondu)

class _StableValue extends StatelessWidget {
  final String value;
  final String unit;
  final ColorScheme colorScheme;
  const _StableValue({
    required this.value,
    required this.unit,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // Largeur mini pour éviter le shift lorsque la valeur raccourcit / s'allonge.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final neonRed = const Color(0xFFFF005C);
    return LayoutBuilder(
      builder: (ctx, c) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 140),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text.rich(
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 100,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.4,
                  color: isDark ? neonRed : null,
                  shadows: isDark
                      ? [
                          Shadow(
                            color: neonRed.withOpacity(0.7),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                children: [
                  if (unit.isNotEmpty)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 6),
                        child: Text(
                          unit,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            color: isDark ? neonRed : colorScheme.onSurfaceVariant,
                            letterSpacing: .7,
                            shadows: isDark
                                ? [
                                    Shadow(
                                      color: neonRed.withOpacity(0.7),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
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
        );
      },
    );
  }
}
