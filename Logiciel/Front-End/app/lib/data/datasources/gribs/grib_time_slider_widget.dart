import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grib_overlay_providers.dart';

/// Widget de contrôle temporel pour naviguer dans les données GRIB
/// Affiche un curseur pour sélectionner le timestamp et affiche la date/heure
class GribTimeSliderWidget extends ConsumerWidget {
  const GribTimeSliderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On observe les timestamps des grilles actuelles
    final uGrid = ref.watch(currentGribUGridProvider);
    final vGrid = ref.watch(currentGribVGridProvider);
    
    if (uGrid == null || vGrid == null) {
      return const SizedBox.shrink();
    }

    // Pour maintenant, on simule 25 timestamps (0 à 72 heures avec pas de 3h)
    // TODO: Récupérer les vrais timestamps depuis les fichiers GRIB
    final forecastHour = ref.watch(gribForecastHourProvider);
    final maxForecastHour = 72;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Prévision: +${forecastHour}h',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Curseur
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: forecastHour.toDouble(),
                  min: 0,
                  max: maxForecastHour.toDouble(),
                  divisions: maxForecastHour ~/ 3, // Pas de 3 heures
                  label: '+${forecastHour}h',
                  onChanged: (value) {
                    ref.read(gribForecastHourProvider.notifier)
                        .setForecastHour(value.toInt());
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: TextButton(
                  onPressed: () {
                    ref.read(gribForecastHourProvider.notifier).setForecastHour(0);
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Info texte
          Text(
            'Glissez le curseur pour naviguer dans les prévisions',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
