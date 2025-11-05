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
    // La légende affiche la vitesse du vent (en m/s ou nds)
    // Pour maintenant on assume que c'est en m/s et on va montrer 0-25 m/s
    final minDisplay = 0;
    final maxDisplay = 25;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre
          Text(
            'Vitesse vent',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          
          // Barre colorimétrique verticale
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
          
          // Labels min et max
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(
                  '${maxDisplay.toInt()} m/s',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '...',
                    style: TextStyle(color: Colors.grey, fontSize: 8),
                  ),
                ),
                Text(
                  '${minDisplay.toInt()} m/s',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
