import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grib_overlay_providers.dart';
import 'grib_file_loader.dart';
import 'dart:io';

/// Widget de contrôle temporel pour naviguer dans les données GRIB
/// Charge les fichiers GRIB correspondant à l'heure de prévision sélectionnée
class GribTimeSliderWidget extends ConsumerWidget {
  const GribTimeSliderWidget({super.key});

  // Heures de prévision disponibles (en heures)
  static const List<int> forecastHours = [
    0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48, 51, 54, 57, 60, 63, 66, 69, 72
  ];

  /// Convertit l'heure en nom de fichier GRIB (f000, f006, etc.)
  static String _hourToFileName(int hour) {
    if (hour == 0) return 'anl';
    return 'f${hour.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On observe les timestamps des grilles actuelles
    final uGrid = ref.watch(currentGribUGridProvider);
    final vGrid = ref.watch(currentGribVGridProvider);
    
    if (uGrid == null || vGrid == null) {
      return const SizedBox.shrink();
    }

    final forecastHour = ref.watch(gribForecastHourProvider);
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Curseur
          Expanded(
            child: Slider(
              value: forecastHour.toDouble(),
              min: 0,
              max: 72,
              divisions: 24, // 3h par pas
              label: '+${forecastHour}h',
              onChanged: (value) async {
                // Arrondir à la plus proche heure valide (multiple de 3)
                final hour = (value / 3).round() * 3;
                await _loadGribForHour(ref, hour);
              },
            ),
          ),
          // Label avec heure actuelle - très petit
          Text(
            '+${forecastHour}h',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Charge le fichier GRIB correspondant à l'heure de prévision
  Future<void> _loadGribForHour(WidgetRef ref, int hour) async {
    print('[GRIB_TIME] 📽️  Chargement prévision: +${hour}h (${_hourToFileName(hour)})');
    
    final files = await GribFileLoader.findGribFiles();
    
    // Chercher le fichier correspondant à l'heure (exclure les fichiers .idx)
    final fileName = _hourToFileName(hour);
    File? gribFile;
    
    try {
      gribFile = files.firstWhere(
        (f) => !f.path.endsWith('.idx') && 
               (f.path.contains(fileName) || (hour == 0 && f.path.contains('anl'))),
      );
    } catch (e) {
      print('[GRIB_TIME] ⚠️  Fichier pas trouvé: $fileName');
      return;
    }

    print('[GRIB_TIME] 📂 Fichier: ${gribFile.path}');

    // Charger la grille scalaire (heatmap)
    final grid = await GribFileLoader.loadGridFromGribFile(gribFile);
    if (grid != null) {
      ref.read(currentGribGridProvider.notifier).setGrid(grid);
      final (vmin, vmax) = grid.getValueBounds();
      ref.read(gribVminProvider.notifier).setVmin(vmin);
      ref.read(gribVmaxProvider.notifier).setVmax(vmax);
      print('[GRIB_TIME] ✅ Grille chargée: ${grid.nx}x${grid.ny}');
    }

    // Charger les vecteurs U/V
    final (uGrid, vGrid) = await GribFileLoader.loadWindVectorsFromGribFile(gribFile);
    if (uGrid != null && vGrid != null) {
      ref.read(currentGribUGridProvider.notifier).setGrid(uGrid);
      ref.read(currentGribVGridProvider.notifier).setGrid(vGrid);
      print('[GRIB_TIME] ✅ Vecteurs chargés');
    } else {
      print('[GRIB_TIME] ⚠️  Erreur chargement vecteurs');
    }

    // Mettre à jour le provider de l'heure
    ref.read(gribForecastHourProvider.notifier).setForecastHour(hour);
  }
}
