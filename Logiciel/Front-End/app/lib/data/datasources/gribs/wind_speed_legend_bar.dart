import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grib_overlay_providers.dart';

/// Barre colorimétrique de légende pour la vitesse du vent
/// Affiche un dégradé blanc→bleu→vert→jaune→rouge→violet
class WindSpeedLegendBar extends ConsumerWidget {
  const WindSpeedLegendBar({super.key});

  /// Crée un dégradé blanc→bleu→vert→jaune→rouge→violet
  static LinearGradient _createWindGradient() {
    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Colors.white,           // 0 nds (bas)
        const Color(0xFF6B9FD1), // Bleu clair
        const Color(0xFF1E7DB8), // Bleu foncé
        Colors.green,           // Vert
        Colors.yellow,          // Jaune
        Colors.orange,          // Orange
        Colors.red,             // Rouge
        const Color(0xFFB73FD8), // Magenta/Violet
      ],
      stops: const [
        0.0,    // 0%
        0.12,   // 12%
        0.25,   // 25%
        0.38,   // 38%
        0.50,   // 50%
        0.62,   // 62%
        0.75,   // 75%
        1.0,    // 100%
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La légende affiche la vitesse du vent en nœuds
    // 1 m/s ≈ 1.94384 nœuds, donc on affiche 0-50 nds (≈ 0-25 m/s)
    final minDisplay = 0;
    final maxDisplay = 50;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre
          Text(
            'Vitesse vent',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          // Label "50 nds" au-dessus
          Text(
            '${maxDisplay.toInt()} nd',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.black,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 40,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                gradient: _createWindGradient(),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Label min
          Text(
            '${minDisplay.toInt()} nd',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.black,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
