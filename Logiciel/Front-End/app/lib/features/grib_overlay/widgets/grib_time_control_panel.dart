import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../data/datasources/gribs/grib_overlay_providers.dart';
import '../../../data/datasources/gribs/grib_file_loader.dart';

/// Widget pour contrôler la navigation temporelle des GRIB (f003, f006, f012, etc.)
class GribTimeControlPanel extends ConsumerStatefulWidget {
  const GribTimeControlPanel({Key? key}) : super(key: key);

  @override
  ConsumerState<GribTimeControlPanel> createState() => _GribTimeControlPanelState();
}

class _GribTimeControlPanelState extends ConsumerState<GribTimeControlPanel> {
  // Heures de prévision disponibles (en heures)
  static const List<int> forecastHours = [
    0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48, 51, 54, 57, 60, 63, 66, 69, 72
  ];

  /// Convertit l'heure en nom de fichier GRIB (f000, f006, etc.)
  static String _hourToFileName(int hour) {
    if (hour == 0) return 'anl';
    return 'f${hour.toString().padLeft(3, '0')}';
  }

  /// Charge le fichier GRIB correspondant à l'heure
  Future<void> _loadGribForHour(int hour) async {
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

  @override
  Widget build(BuildContext context) {
    final currentHour = ref.watch(gribForecastHourProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // === Titre ===
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⏱️  Navigation temporelle',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Prévision +${currentHour}h (${_hourToFileName(currentHour)})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // === Slider ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: currentHour.toDouble(),
              min: 0,
              max: 72,
              divisions: 24, // 3h par pas
              label: '+${currentHour}h',
              onChanged: (value) {
                // Aller au multiple de 3 le plus proche
                final hour = (value / 3).round() * 3;
                _loadGribForHour(hour);
              },
            ),
          ),
        ),

        // === Boutons de navigation rapide ===
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Bouton -12h
              ElevatedButton.icon(
                onPressed: currentHour >= 12
                    ? () => _loadGribForHour(currentHour - 12)
                    : null,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('-12h'),
              ),

              // Bouton -3h
              ElevatedButton.icon(
                onPressed: currentHour >= 3
                    ? () => _loadGribForHour(currentHour - 3)
                    : null,
                icon: const Icon(Icons.arrow_back_ios, size: 14),
                label: const Text('-3h'),
              ),

              // Bouton +3h
              ElevatedButton.icon(
                onPressed: currentHour <= 69
                    ? () => _loadGribForHour(currentHour + 3)
                    : null,
                icon: const Icon(Icons.arrow_forward_ios, size: 14),
                label: const Text('+3h'),
              ),

              // Bouton +12h
              ElevatedButton.icon(
                onPressed: currentHour <= 60
                    ? () => _loadGribForHour(currentHour + 12)
                    : null,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('+12h'),
              ),

              // Bouton Reset
              OutlinedButton.icon(
                onPressed: () => _loadGribForHour(0),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Analyse'),
              ),
            ],
          ),
        ),

        // === Affichage heures rapides ===
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                for (final hour in forecastHours)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: InkWell(
                      onTap: () => _loadGribForHour(hour),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: currentHour == hour
                              ? Theme.of(context).primaryColor
                              : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: currentHour == hour
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          hour == 0 ? 'Anl' : '+${hour}h',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: currentHour == hour
                                ? Colors.white
                                : (isDarkMode ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // === Info ===
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les données se chargent automatiquement. Pas +3h.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}
