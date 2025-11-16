import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grib_overlay_providers.dart';
import 'grib_file_loader.dart';
import 'dart:io';

/// Widget de contrôle temporel pour naviguer dans les données GRIB
/// Charge les fichiers GRIB correspondant à l'heure de prévision sélectionnée
/// Affiche l'heure actuelle et permet des offsets (+3h, -6h, etc.)
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

  /// Extrait la date/heure de début du GRIB depuis le chemin du fichier
  /// Format attendu: .../GFS_0p25/20251115T18/gfs.t18z.pgrb2...
  /// Retourne: DateTime du 15/11/2025 18:00
  static DateTime? _extractGribStartTime(File gribFile) {
    try {
      final path = gribFile.path;
      final parts = path.split('/');
      
      // Chercher la partie avec le format YYYYMMDDTHH (ex: 20251115T18)
      final dateTimePart = parts.firstWhere(
        (p) => RegExp(r'^\d{8}T\d{2}$').hasMatch(p),
        orElse: () => '',
      );
      
      if (dateTimePart.isEmpty) return null;
      
      // Parser: 20251115T18 -> DateTime(2025, 11, 15, 18, 0)
      final year = int.parse(dateTimePart.substring(0, 4));
      final month = int.parse(dateTimePart.substring(4, 6));
      final day = int.parse(dateTimePart.substring(6, 8));
      final hour = int.parse(dateTimePart.substring(9, 11));
      
      return DateTime(year, month, day, hour, 0, 0);
    } catch (e) {
      print('[GRIB_TIME] ⚠️  Impossible d\'extraire la date du GRIB: $e');
      return null;
    }
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
    
    // Utiliser l'heure UTC actuelle (pas locale)
    final nowUtc = DateTime.now().toUtc();
    
    // Calculer l'heure de début du GRIB
    DateTime? gribStartTimeUtc;
    GribFileLoader.findGribFiles().then((files) {
      if (files.isNotEmpty) {
        final extracted = _extractGribStartTime(files.first);
        if (extracted != null) {
          // L'heure extraite est en UTC
          gribStartTimeUtc = extracted;
        }
      }
    });
    
    // Calculer l'offset en heures depuis la date de début du GRIB (en UTC)
    int currentHourOffset = 0;
    if (gribStartTimeUtc != null) {
      currentHourOffset = nowUtc.difference(gribStartTimeUtc!).inHours;
      print('[GRIB_TIME] 🕐 GRIB start: ${gribStartTimeUtc!.toIso8601String()}, Now (UTC): ${nowUtc.toIso8601String()}, Offset: ${currentHourOffset}h');
    } else {
      print('[GRIB_TIME] ⏰ Heure actuelle (UTC): ${nowUtc.toIso8601String()}');
    }
    
    // Convertir l'offset actuel en heure de prévision arrondie (multiple de 3)
    int currentForecastHour = (currentHourOffset / 3).round() * 3;
    
    final forecastTimeUtc = nowUtc.add(Duration(hours: forecastHour));
    
    // Min est l'heure de début du GRIB, max est 72h après
    final minHour = gribStartTimeUtc != null ? currentHourOffset - 72 : -72;
    final maxHour = 72;
    
    // Au premier chargement, charger l'heure actuelle du GRIB
    // (utiliser addPostFrameCallback pour éviter les rebuilds infinis)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (forecastHour == 0 && currentForecastHour != 0) {
        // Charger automatiquement l'heure actuelle du GRIB
        _loadGribForHour(ref, currentForecastHour);
      }
    });
    
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Affichage temps actuel et heure de prévision
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Maintenant (UTC): ${nowUtc.toIso8601String().substring(11, 16)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  'Prévision: ${forecastTimeUtc.toUtc().toIso8601String().substring(11, 16)} (${forecastHour > 0 ? '+' : ''}${forecastHour}h)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Curseur avec position actuelle
          Expanded(
            child: Stack(
              children: [
                // Pointeur de l'heure actuelle (vertical line)
                if (gribStartTimeUtc != null)
                  Align(
                    alignment: Alignment(
                      // Calculer la position relative sur le slider
                      // minHour = left (-1), maxHour = right (1)
                      -1 + (2 * ((currentHourOffset - minHour) / (maxHour - minHour))),
                      0,
                    ),
                    child: Container(
                      width: 2,
                      color: Colors.red.withOpacity(0.7),
                      child: Tooltip(
                        message: 'Heure actuelle',
                        child: Container(),
                      ),
                    ),
                  ),
                // Slider
                Slider(
                  value: forecastHour.toDouble(),
                  min: minHour.toDouble(),
                  max: maxHour.toDouble(),
                  divisions: 24, // 3h par pas
                  label: '${forecastHour > 0 ? '+' : ''}${forecastHour}h',
                  onChanged: (value) async {
                    // Arrondir à la plus proche heure valide (multiple de 3)
                    final hour = (value / 3).round() * 3;
                    await _loadGribForHour(ref, hour);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Charge le fichier GRIB correspondant à l'heure de prévision
  /// Les heures négatives accèdent au passé du GRIB
  Future<void> _loadGribForHour(WidgetRef ref, int hour) async {
    print('[GRIB_TIME] 📽️  Chargement: ${hour > 0 ? '+' : ''}${hour}h (${_hourToFileName(hour.abs())})');
    
    final files = await GribFileLoader.findGribFiles();
    
    // Convertir l'heure relative en heure de prévision
    // Si hour est négatif, chercher dans le passé
    // Si hour est positif, c'est une prévision future
    int forecastHour = hour.abs();
    
    // Chercher le fichier correspondant à l'heure (exclure les fichiers .idx)
    final fileName = _hourToFileName(forecastHour);
    File? gribFile;
    
    try {
      gribFile = files.firstWhere(
        (f) => !f.path.endsWith('.idx') && 
               (f.path.contains(fileName) || (forecastHour == 0 && f.path.contains('anl'))),
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
