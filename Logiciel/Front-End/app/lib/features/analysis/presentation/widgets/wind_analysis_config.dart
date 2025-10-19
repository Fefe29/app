/// Widget de configuration pour l'analyse des tendances du vent
/// Permet d'ajuster la période d'analyse pour le calcul des variations moyennes
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../charts/providers/wind_trend_provider.dart';
import '../../../charts/domain/services/wind_trend_analyzer.dart';
import 'wind_indicators_widgets.dart';

/// Widget de configuration compacte pour l'analyse des tendances
class WindAnalysisConfig extends ConsumerWidget {
  const WindAnalysisConfig({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  final analysisWindowSeconds = ref.watch(windAnalysisWindowProvider);
  final sensitivity = ref.watch(windTrendSensitivityProvider);
  final analysisMinutes = (analysisWindowSeconds / 60).round();

  // TODO: Remplacer ces valeurs par des calculs dynamiques issus des données réelles
  final double stdTwd = 7.2; // exemple d'écart-type TWD
  final double stdTws = 1.8; // exemple d'écart-type TWS
  final double oscAmplitude = 12.0; // exemple amplitude oscillation
  final double oscPeriod = 180.0; // exemple période oscillation (s)

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Configuration Analyse Tendances',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Période d'analyse
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Période d\'analyse',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      '${analysisMinutes}min',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Boutons rapides plus compacts
                    _buildQuickButton(context, ref, '5', 5),
                    const SizedBox(width: 4),
                    _buildQuickButton(context, ref, '10', 10),
                    const SizedBox(width: 4),
                    _buildQuickButton(context, ref, '20', 20),
                    const SizedBox(width: 4),
                    _buildQuickButton(context, ref, '30', 30),
                    const SizedBox(width: 8),
                    // Slider compact
                    Expanded(
                      child: Slider(
                        value: analysisMinutes.toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        onChanged: (value) {
                          ref.read(windAnalysisWindowProvider.notifier).setMinutes(value.round());
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            

            
            const SizedBox(height: 8),
            
            // Sensibilité
            Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensibilité',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Détection des bascules',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      const Text('Faible', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: sensitivity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          onChanged: (value) {
                            ref.read(windTrendSensitivityProvider.notifier).set(value);
                          },
                        ),
                      ),
                      const Text('Forte', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Indicateurs avancés (thermomètre de stabilité, compas oscillation)
            const SizedBox(height: 8),
            WindStabilityThermometer(stdTwd: stdTwd, stdTws: stdTws),
            const SizedBox(height: 8),
            WindOscillationCompassWidget(amplitude: oscAmplitude, period: oscPeriod),
            const SizedBox(height: 8),
            // Infos en temps réel
            _buildAnalysisInfo(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(BuildContext context, WidgetRef ref, String label, int minutes) {
    final currentMinutes = (ref.watch(windAnalysisWindowProvider) / 60).round();
    final isSelected = currentMinutes == minutes;
    
    return GestureDetector(
      onTap: () {
        ref.read(windAnalysisWindowProvider.notifier).setMinutes(minutes);
      },
      child: Container(
        width: 32,
        height: 24,
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisInfo(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final trendSnapshot = ref.watch(windTrendSnapshotProvider);
        
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getTrendColor(trendSnapshot.trend).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _getTrendColor(trendSnapshot.trend).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ligne 1: Tendance + Badge de fiabilité
              Row(
                children: [
                  Icon(
                    _getTrendIcon(trendSnapshot.trend),
                    size: 16,
                    color: _getTrendColor(trendSnapshot.trend),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getTrendLabel(trendSnapshot.trend),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: trendSnapshot.isReliable ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${trendSnapshot.dataCompletenessPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: trendSnapshot.isReliable ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // Ligne 2: Détails techniques compacts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 3,
                    child: Text(
                      '${trendSnapshot.linearSlopeDegPerMin.toStringAsFixed(1)}°/min • ${trendSnapshot.supportPoints}pts',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    flex: 2,
                    child: Text(
                      '${(trendSnapshot.actualDataDurationSeconds/60).toStringAsFixed(1)}/${(trendSnapshot.windowSeconds/60).toStringAsFixed(0)}min',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTrendLabel(WindTrendDirection trend) {
    switch (trend) {
      case WindTrendDirection.veeringRight:
        return 'Bascule Droite (Veering)';
      case WindTrendDirection.backingLeft:
        return 'Bascule Gauche (Backing)';
      case WindTrendDirection.neutral:
        return 'Vent Stable';
      case WindTrendDirection.irregular:
        return 'Vent Irrégulier';
    }
  }

  IconData _getTrendIcon(WindTrendDirection trend) {
    switch (trend) {
      case WindTrendDirection.veeringRight:
        return Icons.trending_up;
      case WindTrendDirection.backingLeft:
        return Icons.trending_down;
      case WindTrendDirection.neutral:
        return Icons.trending_flat;
      case WindTrendDirection.irregular:
        return Icons.show_chart;
    }
  }

  Color _getTrendColor(WindTrendDirection trend) {
    switch (trend) {
      case WindTrendDirection.veeringRight:
        return Colors.red;
      case WindTrendDirection.backingLeft:
        return Colors.blue;
      case WindTrendDirection.neutral:
        return Colors.green;
      case WindTrendDirection.irregular:
        return Colors.orange;
    }
  }
}