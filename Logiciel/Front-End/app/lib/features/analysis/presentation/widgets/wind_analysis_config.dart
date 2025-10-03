/// Widget de configuration pour l'analyse des tendances du vent
/// Permet d'ajuster la période d'analyse pour le calcul des variations moyennes
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../charts/providers/wind_trend_provider.dart';
import '../../../charts/domain/services/wind_trend_analyzer.dart';

/// Widget de configuration compacte pour l'analyse des tendances
class WindAnalysisConfig extends ConsumerWidget {
  const WindAnalysisConfig({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisWindowSeconds = ref.watch(windAnalysisWindowProvider);
    final sensitivity = ref.watch(windTrendSensitivityProvider);
    
    final analysisMinutes = (analysisWindowSeconds / 60).round();

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
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Période d\'analyse',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Calcul de tendance sur ${analysisMinutes}min',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      // Boutons rapides
                      _buildQuickButton(context, ref, '5min', 5),
                      const SizedBox(width: 4),
                      _buildQuickButton(context, ref, '10min', 10),
                      const SizedBox(width: 4),
                      _buildQuickButton(context, ref, '20min', 20),
                      const SizedBox(width: 4),
                      _buildQuickButton(context, ref, '30min', 30),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Slider pour ajustement fin
            Row(
              children: [
                Text('${analysisMinutes}min', style: const TextStyle(fontSize: 12)),
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
                const Text('60min', style: TextStyle(fontSize: 12)),
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
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(windAnalysisWindowProvider.notifier).setMinutes(minutes);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
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
          child: Row(
            children: [
              Icon(
                _getTrendIcon(trendSnapshot.trend),
                size: 16,
                color: _getTrendColor(trendSnapshot.trend),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTrendLabel(trendSnapshot.trend),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${trendSnapshot.linearSlopeDegPerMin.toStringAsFixed(2)}°/min (${trendSnapshot.supportPoints} pts)',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trendSnapshot.isReliable ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  trendSnapshot.isReliable ? 'Fiable' : 'Peu de données',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: trendSnapshot.isReliable ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
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