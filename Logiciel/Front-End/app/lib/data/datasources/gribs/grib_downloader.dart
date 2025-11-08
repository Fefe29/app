import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Variables dispo
enum GribVariable {
  wind10m,     // UGRD/VGRD à 10 m (force du vent)
  windVectors, // Afficher les flèches directionnelles du vent
  mslp,        // PRMSL (niveau: mean sea level)
  windGust,    // GUST (surface)
  precip,      // APCP (surface)
  cloudTotal,  // TCDC (entire atmosphere)
  airTemp2m,   // TMP (2 m)
  cape,        // CAPE (surface)
  waves,       // WW3
  current,     // RTOFS
  seaTemp,     // RTOFS (SST)
}

enum GribModel {
  gfs025,
  gfs050,
  gfs100,
  ecmwfIfs025,   // placeholders (auth requise)
  ecmwfAifs025,  // placeholders (auth requise)
  arpege050,     // placeholders (auth requise)
  arpegeHD006,   // placeholders (auth requise)
  arome0025,     // placeholders (auth requise)
  ww3Global,     // vagues
  rtofsGlobal,   // courants + SST
}

class GribDownloadOptions {
  final GribModel model;
  final DateTime cycleUtc;   // 00/06/12/18Z
  final int days;            // 1..7
  final int stepHours;       // >=1
  final double leftLon;
  final double rightLon;
  final double bottomLat;
  final double topLat;
  final List<GribVariable> variables;
  final Directory outDir;
  final String? authToken;
  final Map<String, String>? extraHeaders;

  GribDownloadOptions({
    required this.model,
    required this.cycleUtc,
    required this.days,
    required this.stepHours,
    required this.leftLon,
    required this.rightLon,
    required this.bottomLat,
    required this.topLat,
    required this.variables,
    required this.outDir,
    this.authToken,
    this.extraHeaders,
  }) {
    if (days < 1 || days > 7) {
      throw ArgumentError('days must be between 1 and 7');
    }
    if (stepHours < 1) {
      throw ArgumentError('stepHours must be >= 1');
    }
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
  }
}

class GribDownloader {
  Future<List<File>> download(GribDownloadOptions opts) async {
    final provider = _providerForModel(opts.model);
    return provider.download(opts);
  }
}

abstract class _BaseProvider {
  Future<List<File>> download(GribDownloadOptions opts);

  Future<File?> _downloadToFile({
    required Uri url,
    required File file,
    Map<String, String>? headers,
  }) async {
    try {
      final res = await http.get(url, headers: headers);
      if (res.statusCode == 200) {
        await file.writeAsBytes(res.bodyBytes);
        return file;
      } else {
        stderr.writeln('HTTP ${res.statusCode} for $url');
        return null;
      }
    } catch (e) {
      stderr.writeln('HTTP error for $url: $e');
      return null;
    }
  }

  Iterable<int> _forecastHours(GribDownloadOptions opts, {int? maxHour}) sync* {
    final totalHours = opts.days * 24;
    final cap = maxHour ?? totalHours;
    for (int h = 0; h <= cap; h += opts.stepHours) {
      yield h;
    }
  }
}

/// -------------------------
/// GFS via NOMADS (GRIB2)
/// -------------------------
class _GfsProvider extends _BaseProvider {
  final String resTag; // "0p25" | "0p50" | "1p00"
  _GfsProvider(this.resTag);

  @override
  Future<List<File>> download(GribDownloadOptions opts) async {
    final runDate = _yyyymmdd(opts.cycleUtc);
    final cycle = opts.cycleUtc.hour.toString().padLeft(2, '0'); // 00/06/12/18
    final baseUrl =
        'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_$resTag.pl';

    // ✅ chemin correct avec /atmos
    final dirParam = '/gfs.$runDate/$cycle/atmos';
    final dirPath = '${opts.outDir.path}/GFS_$resTag/${runDate}T$cycle';
    final outDir = Directory(dirPath)..createSync(recursive: true);

    final List<File> saved = [];
    for (final fh in _forecastHours(opts)) {
      final fhStr = fh.toString().padLeft(3, '0');

      // ✅ f000 => analyse ".anl" pour 0h (spécifique NOMADS)
      final fileName = (fh == 0)
          ? 'gfs.t${cycle}z.pgrb2.$resTag.anl'
          : 'gfs.t${cycle}z.pgrb2.$resTag.f$fhStr';

      final params = _buildGfsQuery(opts, fileName, dirParam);
      final uri = Uri.parse('$baseUrl?${_encode(params)}');

      final outFile = File('${outDir.path}/$fileName');
      final f = await _downloadToFile(url: uri, file: outFile);
      if (f != null) saved.add(f);
    }
    return saved;
  }

  Map<String, String> _buildGfsQuery(
      GribDownloadOptions opts, String fileName, String dirParam) {
    final params = <String, String>{
      'file': fileName,
      'subregion': '',
      'leftlon': opts.leftLon.toString(),
      'rightlon': opts.rightLon.toString(),
      'toplat': opts.topLat.toString(),
      'bottomlat': opts.bottomLat.toString(),
      'dir': dirParam,
    };

    if (opts.variables.contains(GribVariable.wind10m)) {
      params['lev_10_m_above_ground'] = 'on';
      params['var_UGRD'] = 'on';
      params['var_VGRD'] = 'on';
    }
    if (opts.variables.contains(GribVariable.airTemp2m)) {
      params['lev_2_m_above_ground'] = 'on';
      params['var_TMP'] = 'on';
    }
    if (opts.variables.contains(GribVariable.mslp)) {
      // ✅ niveau MSL requis pour PRMSL
      params['lev_mean_sea_level'] = 'on';
      params['var_PRMSL'] = 'on';
    }
    if (opts.variables.contains(GribVariable.windGust)) {
      params['lev_surface'] = 'on';
      params['var_GUST'] = 'on';
    }
    if (opts.variables.contains(GribVariable.precip)) {
      params['lev_surface'] = 'on';
      params['var_APCP'] = 'on';
    }
    if (opts.variables.contains(GribVariable.cloudTotal)) {
      params['lev_entire_atmosphere'] = 'on';
      params['var_TCDC'] = 'on';
    }
    if (opts.variables.contains(GribVariable.cape)) {
      params['lev_surface'] = 'on';
      params['var_CAPE'] = 'on';
    }

    // Vagues / courants / SST non fournis par GFS -> autres providers
    return params;
  }
}

/// -------------------------
/// WW3 (vagues GRIB2)
/// -------------------------
class _Ww3Provider extends _BaseProvider {
  @override
  Future<List<File>> download(GribDownloadOptions opts) async {
    if (!opts.variables.contains(GribVariable.waves)) return [];

    final runDate = _yyyymmdd(opts.cycleUtc);
    final cycle = opts.cycleUtc.hour.toString().padLeft(2, '0');
    final baseUrl =
        'https://nomads.ncep.noaa.gov/cgi-bin/filter_wave_multi.pl';

    final dirParam = '/multi_1.$runDate/$cycle';
    final dirPath = '${opts.outDir.path}/WW3/${runDate}T$cycle';
    final outDir = Directory(dirPath)..createSync(recursive: true);

    final List<File> saved = [];
    for (final fh in _forecastHours(opts)) {
      final fhStr = fh.toString().padLeft(3, '0');
      final fileName =
          'multi_1.glo_30m.t${cycle}z.f$fhStr.grib2'; // Hs/Dir/Per global

      final params = <String, String>{
        'file': fileName,
        'subregion': '',
        'leftlon': opts.leftLon.toString(),
        'rightlon': opts.rightLon.toString(),
        'toplat': opts.topLat.toString(),
        'bottomlat': opts.bottomLat.toString(),
        'dir': dirParam,
        'var_HTSGW': 'on',
        'var_DIRPW': 'on',
        'var_PERPW': 'on',
      };

      final uri = Uri.parse('$baseUrl?${_encode(params)}');
      final outFile = File('${outDir.path}/$fileName');
      final f = await _downloadToFile(url: uri, file: outFile);
      if (f != null) saved.add(f);
    }
    return saved;
  }
}

/// -------------------------
/// RTOFS (courants + SST)
/// -------------------------
class _RtofsProvider extends _BaseProvider {
  @override
  Future<List<File>> download(GribDownloadOptions opts) async {
    if (!opts.variables.any((v) => v == GribVariable.current || v == GribVariable.seaTemp)) {
      return [];
    }

    final runDate = _yyyymmdd(opts.cycleUtc);
    final baseUrl =
        'https://nomads.ncep.noaa.gov/cgi-bin/filter_rtofs_global.pl';
    final dirParam = '/rtofs.$runDate';

    final dirPath = '${opts.outDir.path}/RTOFS/$runDate';
    final outDir = Directory(dirPath)..createSync(recursive: true);

    final List<File> saved = [];
    for (final fh in _forecastHours(opts)) {
      final fhStr = fh.toString().padLeft(3, '0');
      final fileName = 'rtofs_glo_2ds_f${fhStr}_3hrly_prog.grb2';

      final params = <String, String>{
        'file': fileName,
        'subregion': '',
        'leftlon': opts.leftLon.toString(),
        'rightlon': opts.rightLon.toString(),
        'toplat': opts.topLat.toString(),
        'bottomlat': opts.bottomLat.toString(),
        'dir': dirParam,
      };

      if (opts.variables.contains(GribVariable.current)) {
        params['var_UGRD'] = 'on';
        params['var_VGRD'] = 'on';
      }
      if (opts.variables.contains(GribVariable.seaTemp)) {
        params['var_TMP'] = 'on';
      }

      final uri = Uri.parse('$baseUrl?${_encode(params)}');
      final outFile = File('${outDir.path}/$fileName');
      final f = await _downloadToFile(url: uri, file: outFile);
      if (f != null) saved.add(f);
    }
    return saved;
  }
}

/// -------------------------
/// ECMWF & MF placeholders
/// -------------------------
class _EcmwfProvider extends _BaseProvider {
  final String modelName; // "IFS_0p25" | "AIFS_0p25"
  final Uri baseEndpoint; // à remplacer par ton proxy
  _EcmwfProvider(this.modelName, this.baseEndpoint);

  @override
  Future<List<File>> download(GribDownloadOptions opts) async {
    if (opts.authToken == null) {
      stderr.writeln('[$modelName] Missing authToken. Skipping.');
      return [];
    }
    final List<File> saved = [];
    for (final fh in _forecastHours(opts)) {
      final payload = {
        'model': modelName,
        'run':
            '${_yyyymmdd(opts.cycleUtc)}T${opts.cycleUtc.toUtc().hour.toString().padLeft(2, '0')}Z',
        'fh': fh,
        'bbox': {
          'left': opts.leftLon,
          'right': opts.rightLon,
          'bottom': opts.bottomLat,
          'top': opts.topLat,
        },
        'vars': opts.variables.map((v) => v.name).toList(),
        'stepHours': opts.stepHours,
      };
      final res = await http.post(
        baseEndpoint,
        headers: {
          'Authorization': 'Bearer ${opts.authToken}',
          'Content-Type': 'application/json',
          ...(opts.extraHeaders ?? {}),
        },
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        final file = File(
            '${opts.outDir.path}/$modelName/${_yyyymmdd(opts.cycleUtc)}/$modelName-f${fh.toString().padLeft(3, '0')}.grib2')
          ..parent.createSync(recursive: true);
        await file.writeAsBytes(res.bodyBytes);
        saved.add(file);
      } else {
        stderr.writeln('[$modelName] HTTP ${res.statusCode} ${res.reasonPhrase}');
      }
    }
    return saved;
  }
}

class _MeteoFranceProvider extends _BaseProvider {
  final String modelName; // "ARPEGE_0p50" | "ARPEGEHD_0p06" | "AROME_0p025"
  final Uri baseEndpoint;
  _MeteoFranceProvider(this.modelName, this.baseEndpoint);

  @override
  Future<List<File>> download(GribDownloadOptions opts) async {
    if (opts.authToken == null) {
      stderr.writeln('[$modelName] Missing authToken. Skipping.');
      return [];
    }
    final List<File> saved = [];
    for (final fh in _forecastHours(opts)) {
      final payload = {
        'model': modelName,
        'run':
            '${_yyyymmdd(opts.cycleUtc)}T${opts.cycleUtc.toUtc().hour.toString().padLeft(2, '0')}Z',
        'fh': fh,
        'bbox': {
          'left': opts.leftLon,
          'right': opts.rightLon,
          'bottom': opts.bottomLat,
          'top': opts.topLat,
        },
        'vars': opts.variables.map((v) => v.name).toList(),
        'stepHours': opts.stepHours,
      };
      final res = await http.post(
        baseEndpoint,
        headers: {
          'Authorization': 'Bearer ${opts.authToken}',
          'Content-Type': 'application/json',
          ...(opts.extraHeaders ?? {}),
        },
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        final file = File(
            '${opts.outDir.path}/$modelName/${_yyyymmdd(opts.cycleUtc)}/$modelName-f${fh.toString().padLeft(3, '0')}.grib2')
          ..parent.createSync(recursive: true);
        await file.writeAsBytes(res.bodyBytes);
        saved.add(file);
      } else {
        stderr.writeln('[$modelName] HTTP ${res.statusCode} ${res.reasonPhrase}');
      }
    }
    return saved;
  }
}

_BaseProvider _providerForModel(GribModel model) {
  switch (model) {
    case GribModel.gfs025:
      return _GfsProvider('0p25');
    case GribModel.gfs050:
      return _GfsProvider('0p50');
    case GribModel.gfs100:
      return _GfsProvider('1p00');
    case GribModel.ww3Global:
      return _Ww3Provider();
    case GribModel.rtofsGlobal:
      return _RtofsProvider();
    case GribModel.ecmwfIfs025:
      return _EcmwfProvider('IFS_0p25', Uri.parse('https://your-proxy/ecmwf/ifs'));
    case GribModel.ecmwfAifs025:
      return _EcmwfProvider('AIFS_0p25', Uri.parse('https://your-proxy/ecmwf/aifs'));
    case GribModel.arpege050:
      return _MeteoFranceProvider('ARPEGE_0p50', Uri.parse('https://your-proxy/meteo-france/arpege'));
    case GribModel.arpegeHD006:
      return _MeteoFranceProvider('ARPEGEHD_0p06', Uri.parse('https://your-proxy/meteo-france/arpege-hd'));
    case GribModel.arome0025:
      return _MeteoFranceProvider('AROME_0p025', Uri.parse('https://your-proxy/meteo-france/arome'));
  }
}

String _yyyymmdd(DateTime dt) {
  final u = dt.toUtc();
  return '${u.year.toString().padLeft(4, '0')}${u.month.toString().padLeft(2, '0')}${u.day.toString().padLeft(2, '0')}';
}
String _encode(Map<String, String> p) =>
    p.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');

/// Extension pour afficher les noms lisibles des variables GRIB
extension GribVariableDisplay on GribVariable {
  String get displayName {
    switch (this) {
      case GribVariable.wind10m:
        return 'Vent à 10 m';
      case GribVariable.windVectors:
        return 'Vecteurs de vent';
      case GribVariable.mslp:
        return 'Pression au niveau de la mer';
      case GribVariable.windGust:
        return 'Rafales de vent';
      case GribVariable.precip:
        return 'Précipitations';
      case GribVariable.cloudTotal:
        return 'Couverture nuageuse totale';
      case GribVariable.airTemp2m:
        return 'Température à 2 m';
      case GribVariable.cape:
        return 'CAPE (Énergie potentielle convective)';
      case GribVariable.waves:
        return 'Vagues (WW3)';
      case GribVariable.current:
        return 'Courants (RTOFS)';
      case GribVariable.seaTemp:
        return 'Température de la mer (SST)';
    }
  }
}

