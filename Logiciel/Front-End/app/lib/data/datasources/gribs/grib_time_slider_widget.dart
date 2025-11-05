import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grib_overlay_providers.dart';
import 'grib_file_loader.dart';
import 'dart:io';

/// Widget de contrôle temporel pour naviguer dans les données GRIB
/// Charge les fichiers GRIB correspondant à l'heure de prévision sélectionnée
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
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
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
              max: maxForecastHour.toDouble(),
              divisions: maxForecastHour ~/ 3, // Pas de 3 heures
              label: '+${forecastHour}h',
              onChanged: (value) async {
                final hour = value.toInt();
                
                // Mets à jour l'heure de prévision
                ref.read(gribForecastHourProvider.notifier)
                    .setForecastHour(hour);
                
                // Charge le fichier GRIB correspondant
                await _loadGribForForecastHour(ref, hour);
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
  Future<void> _loadGribForForecastHour(WidgetRef ref, int forecastHour) async {
    try {
      // Trouve les fichiers GRIB disponibles
      final files = await GribFileLoader.findGribFiles();
      
      if (files.isEmpty) {
        print('[GRIB_TIME] Aucun fichier GRIB trouvé');
        return;
      }
      
      // Cherche un fichier qui correspond à l'heure de prévision (f0XX où XX = heure)
      // Format typique: gfs.t06z.pgrb2.0p25.f069 (f069 = 69 heures de prévision)
      File? selectedFile;
      
      for (final file in files) {
        final fileName = file.path.split('/').last;
        
        // Extrait le numéro de prévision (f0XX)
        final match = RegExp(r'\.f(\d+)').firstMatch(fileName);
        if (match != null) {
          final fileForecastHour = int.tryParse(match.group(1) ?? '0') ?? 0;
          
          if (fileForecastHour == forecastHour) {
            selectedFile = file;
            break;
          }
        }
      }
      
      if (selectedFile == null) {
        print('[GRIB_TIME] Pas de fichier GRIB pour f${forecastHour.toString().padLeft(3, '0')}');
        return;
      }
      
      print('[GRIB_TIME] Chargement GRIB: ${selectedFile.path}');
      
      // Charge le GRIB
      final grid = await GribFileLoader.loadGridFromGribFile(selectedFile);
      if (grid != null) {
        ref.read(currentGribGridProvider.notifier).setGrid(grid);
        final (vmin, vmax) = grid.getValueBounds();
        ref.read(gribVminProvider.notifier).setVmin(vmin);
        ref.read(gribVmaxProvider.notifier).setVmax(vmax);
      }
      
      // Charge aussi les grilles U et V
      final (uGrid, vGrid) = await GribFileLoader.loadWindVectorsFromGribFile(selectedFile);
      if (uGrid != null) ref.read(currentGribUGridProvider.notifier).setGrid(uGrid);
      if (vGrid != null) ref.read(currentGribVGridProvider.notifier).setGrid(vGrid);
      
    } catch (e) {
      print('[GRIB_TIME] Erreur en chargeant GRIB: $e');
    }
  }
}
