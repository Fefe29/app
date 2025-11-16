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
  /// Retourne: DateTime du 15/11/2025 18:00 UTC
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
      
      // Parser: 20251115T18 -> DateTime.utc(2025, 11, 15, 18, 0, 0)
      final year = int.parse(dateTimePart.substring(0, 4));
      final month = int.parse(dateTimePart.substring(4, 6));
      final day = int.parse(dateTimePart.substring(6, 8));
      final hour = int.parse(dateTimePart.substring(9, 11));
      
      return DateTime.utc(year, month, day, hour, 0, 0);
    } catch (e) {
      print('[GRIB_TIME] ⚠️  Impossible d\'extraire la date du GRIB: $e');
      return null;
    }
  }

  /// Extrait l'heure de prévision depuis le nom du fichier GRIB
  /// Formats: f000, f003, f006, ..., f072 ou anl (=0)
  /// Retourne l'heure en heures
  static int? _extractForecastHourFromFilename(String filename) {
    try {
      if (filename.contains('anl')) return 0;
      
      final match = RegExp(r'f(\d{3})').firstMatch(filename);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('[GRIB_SLIDER] 🔄 BUILD CALLED');
    
    // On observe les timestamps des grilles actuelles
    final uGrid = ref.watch(currentGribUGridProvider);
    final vGrid = ref.watch(currentGribVGridProvider);
    
    print('[GRIB_SLIDER] uGrid=$uGrid, vGrid=$vGrid');
    
    if (uGrid == null || vGrid == null) {
      print('[GRIB_SLIDER] ⚠️  uGrid ou vGrid null -> SizedBox.shrink()');
      return const SizedBox.shrink();
    }

    // Observer le dernier fichier GRIB chargé pour détecter les changements
    final lastLoadedFile = ref.watch(lastLoadedGribFileProvider);
    print('[GRIB_SLIDER] lastLoadedFile=$lastLoadedFile');
    print('[GRIB_SLIDER] 🔑 ValueKey will be: grib_slider_${lastLoadedFile?.path ?? "none"}');
    
    final forecastHour = ref.watch(gribForecastHourProvider);
    
    // Utiliser l'heure UTC actuelle (pas locale)
    final nowUtc = DateTime.now().toUtc();
    print('[GRIB_SLIDER] forecastHour=$forecastHour, nowUtc=${nowUtc.toIso8601String()}');
    
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('grib_slider_${lastLoadedFile?.path ?? "none"}'), // Force rebuild si fichier GRIB change
      future: _computeGribTimeRange(ref),
      builder: (context, snapshot) {
        print('[GRIB_SLIDER] FutureBuilder state: hasData=${snapshot.hasData}, hasError=${snapshot.hasError}, connectionState=${snapshot.connectionState}');
        
        if (!snapshot.hasData) {
          print('[GRIB_SLIDER] ⚠️  Pas de data -> SizedBox.shrink()');
          return const SizedBox.shrink();
        }
        
        final data = snapshot.data!;
        final gribStartTimeUtc = data['startTime'] as DateTime?;
        final sortedFiles = data['sortedFiles'] as List<MapEntry<int, File>>;
        
        print('[GRIB_SLIDER] ✅ Data received: gribStart=$gribStartTimeUtc, files=${sortedFiles.length}');
        print('[GRIB_SLIDER] 📝 Files:');
        for (int i = 0; i < sortedFiles.length; i++) {
          print('[GRIB_SLIDER]   [$i] ${sortedFiles[i].key}h: ${sortedFiles[i].value.path.split('/').last}');
        }
        
        // Vérification: pas de fichiers disponibles
        if (sortedFiles.isEmpty) {
          print('[GRIB_SLIDER] ⚠️  Aucun fichier GRIB disponible -> SizedBox.shrink()');
          return const SizedBox.shrink();
        }
        
        // Trouver l'index du fichier actuel basé sur forecastHour
        int currentIndex = 0;
        for (int i = 0; i < sortedFiles.length; i++) {
          if (sortedFiles[i].key == forecastHour) {
            currentIndex = i;
            break;
          }
        }
        print('[GRIB_SLIDER] � currentIndex=$currentIndex (forecastHour=$forecastHour), totalFiles=${sortedFiles.length}');
        
        final nowUtc = DateTime.now().toUtc();
        final currentFileHour = sortedFiles[currentIndex].key;
        final forecastTimeUtc = gribStartTimeUtc != null
            ? gribStartTimeUtc.add(Duration(hours: currentFileHour))
            : nowUtc.add(Duration(hours: currentFileHour));
        print('[GRIB_SLIDER] 📅 forecastTimeUtc=$forecastTimeUtc, currentFileHour=$currentFileHour');
        
        return Container(
          height: 60,
          padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.3),
                width: 1.0,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Row avec fleches + slider transparent
              Row(
                children: [
                  // Fleche gauche
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: currentIndex > 0
                        ? () async {
                            final newIndex = currentIndex - 1;
                            final hour = sortedFiles[newIndex].key;
                            print('[GRIB_SLIDER] Left arrow: index=$newIndex, hour=$hour');
                            await _loadGribForHour(ref, hour);
                          }
                        : null,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  
                  // Slider transparent avec tooltip qui suit la souris
                  Expanded(
                    child: _SliderWithDynamicTooltip(
                      currentIndex: currentIndex,
                      sortedFiles: sortedFiles,
                      gribStartTimeUtc: gribStartTimeUtc,
                      nowUtc: nowUtc,
                      onChanged: (value) async {
                        final index = value.round();
                        if (index >= 0 && index < sortedFiles.length) {
                          final hour = sortedFiles[index].key;
                          print('[GRIB_SLIDER] Slider moved: index=$index, hour=$hour');
                          await _loadGribForHour(ref, hour);
                        }
                      },
                    ),
                  ),
                  
                  // Fleche droite
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: currentIndex < sortedFiles.length - 1
                        ? () async {
                            final newIndex = currentIndex + 1;
                            final hour = sortedFiles[newIndex].key;
                            print('[GRIB_SLIDER] Right arrow: index=$newIndex, hour=$hour');
                            await _loadGribForHour(ref, hour);
                          }
                        : null,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// Scanne les fichiers GRIB pour déterminer la plage de temps disponible
  /// Filtre pour ne charger que les fichiers du cycle GRIB actuellement actif
  /// ET applique la résolution adaptative selon la durée par défaut (5 jours)
  Future<Map<String, dynamic>> _computeGribTimeRange(WidgetRef ref) async {
    print('[GRIB_SLIDER] 🔍 _computeGribTimeRange() CALLED');
    
    // Observer le répertoire GRIB actif
    final activeDir = ref.watch(activeGribDirectoryProvider);
    print('[GRIB_SLIDER] 📂 activeDir=$activeDir');
    
    if (activeDir == null) {
      print('[GRIB_SLIDER] ⚠️  activeGribDirectoryProvider est null -> retour vide');
      return {'startTime': null, 'sortedFiles': <MapEntry<int, File>>[]};
    }
    
    // Durée par défaut: 5 jours = 120 heures (horizon par défaut)
    const int defaultHorizonDays = 5;
    final int maxHour = defaultHorizonDays * 24;
    
    print('[GRIB_SLIDER] 🎯 Horizon par défaut: $defaultHorizonDays jours ($maxHour heures max)');
    
    // Calculer les heures qui doivent être affichées selon l'algo adaptif
    final targetHours = <int>{};
    
    // Résolution adaptative & décroissante:
    // 0-12h: toutes les 1h
    // 12-36h: toutes les 3h
    // 36-84h: toutes les 6h
    // 84-180h: toutes les 12h
    // 180+: toutes les 24h
    
    for (int h = 0; h <= maxHour; h++) {
      if (h <= 12) {
        targetHours.add(h);  // 0-12h: chaque heure
      } else if (h <= 36) {
        if (h % 3 == 0) targetHours.add(h);  // 12-36h: toutes les 3h
      } else if (h <= 84) {
        if (h % 6 == 0) targetHours.add(h);  // 36-84h: toutes les 6h
      } else if (h <= 180) {
        if (h % 12 == 0) targetHours.add(h);  // 84-180h: toutes les 12h
      } else {
        if (h % 24 == 0) targetHours.add(h);  // 180+: toutes les 24h
      }
    }
    
    print('[GRIB_SLIDER] 📊 Target hours (adaptive, 5 days): $targetHours');
    
    // Lister SEULEMENT les fichiers du répertoire actif
    final files = <File>[];
    for (final file in activeDir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.idx') && file.path.contains('pgrb2')) {
        files.add(file);
      }
    }
    print('[GRIB_SLIDER] 📂 Found ${files.length} GRIB files in active directory');
    
    // Filtrer: garder seulement les fichiers GRIB valides (pas .idx, pas vides)
    // ET seulement les heures de la résolution adaptative
    final validFiles = <File>[];
    final hourValues = <int>[];
    
    for (final file in files) {
      // Vérifier que le fichier n'est pas vide
      if (file.lengthSync() == 0) {
        print('[GRIB_SLIDER] ⚠️  File ${file.path.split('/').last} is empty, skipped');
        continue;
      }
      
      // Extraire l'heure de prévision
      final hour = _extractForecastHourFromFilename(file.path);
      if (hour != null && targetHours.contains(hour)) {
        // ✅ Ajouter seulement si l'heure correspond à la résolution adaptative
        validFiles.add(file);
        hourValues.add(hour);
      }
    }
    
    // Trier par heure
    final sortedPairs = <MapEntry<int, File>>[];
    for (int i = 0; i < hourValues.length; i++) {
      sortedPairs.add(MapEntry(hourValues[i], validFiles[i]));
    }
    sortedPairs.sort((a, b) => a.key.compareTo(b.key));
    
    print('[GRIB_SLIDER] 📊 Filtered files by hour (adaptive): ${sortedPairs.map((p) => '${p.key}h:${p.value.path.split('/').last}').toList()}');
    
    // Extraire heure de début si possible
    DateTime? startTime;
    if (sortedPairs.isNotEmpty) {
      startTime = _extractGribStartTime(sortedPairs.first.value);
    }
    
    return {
      'startTime': startTime,
      'sortedFiles': sortedPairs, // Liste de MapEntry(hour, file)
    };
  }
  
  /// Charge le fichier GRIB correspondant à l'heure de prévision
  /// Les heures négatives accèdent au passé du GRIB
  /// Réinitialise les paramètres (vmin/vmax) du nouveau GRIB
  Future<void> _loadGribForHour(WidgetRef ref, int hour) async {
    print('[GRIB_TIME] 📽️  Chargement: ${hour > 0 ? '+' : ''}${hour}h (${_hourToFileName(hour.abs())})');
    
    // Récupérer le répertoire GRIB actif
    final activeDir = ref.watch(activeGribDirectoryProvider);
    if (activeDir == null) {
      print('[GRIB_TIME] ⚠️  activeGribDirectoryProvider est null');
      return;
    }
    
    // Lister les fichiers du répertoire actif
    final files = <File>[];
    for (final file in activeDir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.idx') && 
          file.path.contains('pgrb2') &&
          file.lengthSync() > 0) {
        files.add(file);
      }
    }
    
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
      // ℹ️ NOTE: On ne réinitialise PAS vmin/vmax pour conserver les paramètres de couleur choisis
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

/// Widget Slider personnalisé avec tooltip qui suit la souris dynamiquement
class _SliderWithDynamicTooltip extends StatefulWidget {
  final int currentIndex;
  final List<MapEntry<int, File>> sortedFiles;
  final DateTime? gribStartTimeUtc;
  final DateTime nowUtc;
  final ValueChanged<double> onChanged;

  const _SliderWithDynamicTooltip({
    required this.currentIndex,
    required this.sortedFiles,
    required this.gribStartTimeUtc,
    required this.nowUtc,
    required this.onChanged,
  });

  @override
  State<_SliderWithDynamicTooltip> createState() => _SliderWithDynamicTooltipState();
}

class _SliderWithDynamicTooltipState extends State<_SliderWithDynamicTooltip> {
  bool isHovering = false;
  Offset? mousePosition;
  double? hoverValue;
  OverlayEntry? overlayEntry;

  @override
  void dispose() {
    overlayEntry?.remove();
    super.dispose();
  }

  void _updateTooltip() {
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }

    if (!isHovering || mousePosition == null || hoverValue == null) {
      return;
    }

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: mousePosition!.dx - 50,
        top: mousePosition!.dy - 40,
        child: _buildTooltip(hoverValue!),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);
  }

  void _hideTooltip() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        setState(() => isHovering = true);
        _updateTooltip();
      },
      onExit: (event) {
        setState(() {
          isHovering = false;
          mousePosition = null;
          hoverValue = null;
        });
        _hideTooltip();
      },
      onHover: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;

        final localPosition = box.globalToLocal(event.position);
        final sliderWidth = box.size.width;
        final padding = 16.0;

        final relativeX = (localPosition.dx - padding / 2).clamp(0.0, sliderWidth - padding);
        final ratio = relativeX / (sliderWidth - padding);
        final newValue = ratio * (widget.sortedFiles.length - 1);

        setState(() {
          mousePosition = event.position;
          hoverValue = newValue.clamp(0.0, (widget.sortedFiles.length - 1).toDouble());
        });

        _updateTooltip();
      },
      child: Slider(
        value: widget.currentIndex.toDouble(),
        min: 0.0,
        max: (widget.sortedFiles.length - 1).toDouble(),
        divisions: widget.sortedFiles.length <= 1 ? 1 : widget.sortedFiles.length - 1,
        activeColor: Colors.blue,
        inactiveColor: Colors.transparent,
        overlayColor: MaterialStateColor.resolveWith((states) => Colors.blue.withOpacity(0.3)),
        onChanged: widget.onChanged,
      ),
    );
  }

  Widget _buildTooltip(double value) {
    final index = value.round().clamp(0, widget.sortedFiles.length - 1);
    final hour = widget.sortedFiles[index].key;
    
    final forecastTimeUtc = widget.gribStartTimeUtc != null
        ? widget.gribStartTimeUtc!.add(Duration(hours: hour))
        : widget.nowUtc.add(Duration(hours: hour));

    // Convertir en heure locale
    final forecastTimeLocal = forecastTimeUtc.toLocal();

    final tooltipText = '${forecastTimeLocal.day}/${forecastTimeLocal.month} ${forecastTimeLocal.hour.toString().padLeft(2, '0')}:${forecastTimeLocal.minute.toString().padLeft(2, '0')} (UTC +${hour}h)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        tooltipText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
        ),
      ),
    );
  }
}

