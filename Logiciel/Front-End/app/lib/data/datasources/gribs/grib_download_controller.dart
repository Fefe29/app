import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grib_downloader.dart';
import 'grib_overlay_providers.dart';
import 'package:http/http.dart' as http;
import '../../../common/kornog_data_directory.dart';

class GribDownloadState {
  final bool isLoading;
  final String? message;
  final List<File> lastFiles;

  const GribDownloadState({
    required this.isLoading,
    required this.lastFiles,
    this.message,
  });

  GribDownloadState copyWith({
    bool? isLoading,
    String? message,
    List<File>? lastFiles,
  }) =>
      GribDownloadState(
        isLoading: isLoading ?? this.isLoading,
        message: message,
        lastFiles: lastFiles ?? this.lastFiles,
      );

  static const initial = GribDownloadState(isLoading: false, lastFiles: []);
}

class GribDownloadController extends Notifier<GribDownloadState> {
  late final GribDownloader _downloader;

  @override
  GribDownloadState build() {
    _downloader = GribDownloader();
    return GribDownloadState.initial;
  }

  DateTime latestSynopticCycleUtc(DateTime nowUtc) {
    const cycles = [0, 6, 12, 18];
    int chosen = cycles.first;
    for (final c in cycles) {
      if (c <= nowUtc.hour) chosen = c;
    }
    final dt = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, chosen);
    if (dt.isAfter(nowUtc)) {
      final y = nowUtc.subtract(const Duration(days: 1));
      return DateTime.utc(y.year, y.month, y.day, 18);
    }
    return dt;
  }

  /// Optionnel: on sonde NOMADS pour s’assurer que le run est dispo
  Future<DateTime> findAvailableGfsCycleUtc(DateTime nowUtc) async {
    final candidates = <DateTime>[];
    for (final h in const [18, 12, 6, 0]) {
      final dt = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, h);
      if (!dt.isAfter(nowUtc)) candidates.add(dt);
    }
    final y = nowUtc.subtract(const Duration(days: 1));
    for (final h in const [18, 12, 6, 0]) {
      candidates.add(DateTime.utc(y.year, y.month, y.day, h));
    }
    for (final c in candidates.take(6)) {
      final ok = await _probeNomadsDir(c);
      if (ok) return c;
    }
    return latestSynopticCycleUtc(nowUtc);
  }

  Future<bool> _probeNomadsDir(DateTime cycleUtc) async {
    final runDate = _yyyymmdd(cycleUtc);
    final h = cycleUtc.hour.toString().padLeft(2, '0');
    final test = Uri.parse(
      'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl'
      '?file=gfs.t${h}z.pgrb2.0p25.f003'
      '&lev_10_m_above_ground=on&var_UGRD=on&var_VGRD=on'
      '&subregion=&leftlon=0&rightlon=1&toplat=1&bottomlat=0'
      '&dir=%2Fgfs.$runDate%2F$h%2Fatmos',
    );
    try {
      final res = await http.head(test).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> download({
    required GribModel model,
    required Set<GribVariable> variables,
    required int days,
    required int stepHours,
    required double leftLon,
    required double rightLon,
    required double bottomLat,
    required double topLat,
    Directory? outDirOverride,
    String? authToken,
    Map<String, String>? extraHeaders,
  }) async {
    if (variables.isEmpty) {
      state = state.copyWith(message: 'Aucune variable sélectionnée.');
      return;
    }

    state = state.copyWith(isLoading: true, message: null);

    try {
      final out = outDirOverride ?? await getGribDataDirectory();

      DateTime cycle = latestSynopticCycleUtc(DateTime.now().toUtc());
      // Pour GFS uniquement, on tente une sonde pour éviter 404 si run pas prêt
      if (model == GribModel.gfs025 ||
          model == GribModel.gfs050 ||
          model == GribModel.gfs100) {
        cycle = await findAvailableGfsCycleUtc(DateTime.now().toUtc());
      }

      final files = await _downloader.download(
        GribDownloadOptions(
          model: model,
          cycleUtc: cycle,
          days: days,
          stepHours: stepHours,
          leftLon: leftLon,
          rightLon: rightLon,
          bottomLat: bottomLat,
          topLat: topLat,
          variables: variables.toList(),
          outDir: out,
          authToken: authToken,
          extraHeaders: extraHeaders,
        ),
      );

      if (files.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          lastFiles: const [],
          message:
              'Aucun fichier téléchargé. Vérifie modèle/cycle/variables (pense à /atmos et anl).',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          lastFiles: files,
          message: 'Téléchargé ${files.length} fichier(s).',
        );
        
        // Charger automatiquement le premier fichier téléchargé
        print('[GRIB_DL] 📥 Chargement automatique du premier fichier téléchargé');
        try {
          await loadGribFile(files.first, this.ref);
          print('[GRIB_DL] ✅ Fichier chargé avec succès');
        } catch (e) {
          print('[GRIB_DL] ❌ Erreur lors du chargement: $e');
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        message: 'Erreur: $e',
      );
    }
  }
}

final gribDownloadControllerProvider =
    NotifierProvider<GribDownloadController, GribDownloadState>(
  () => GribDownloadController(),
);

String _yyyymmdd(DateTime dt) {
  final u = dt.toUtc();
  return '${u.year.toString().padLeft(4, '0')}${u.month.toString().padLeft(2, '0')}${u.day.toString().padLeft(2, '0')}';
}
