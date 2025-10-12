import 'dart:io';
import 'grib_downloader.dart';

/// Petit runner de test pour vérifier le téléchargement des GRIBs.
/// À exécuter depuis la racine du projet:
///   dart run lib/data/datasources/gribs/grib_downloader_test_runner.dart
/// ou avec Flutter:
///   flutter run -d linux -t lib/data/datasources/gribs/grib_downloader_test_runner.dart
///   flutter run -d macos -t lib/data/datasources/gribs/grib_downloader_test_runner.dart
///   flutter run -d windows -t lib/data/datasources/gribs/grib_downloader_test_runner.dart
///
/// Le dossier de sortie est: lib/data/datasources/gribs/repositories

Future<void> main() async {
  print('=== GRIB Test Runner ===');

  // 1) Calcule le dernier cycle GFS disponible (00Z, 06Z, 12Z ou 18Z)
  final nowUtc = DateTime.now().toUtc();
  final cycleUtc = _latestGfsCycleUtc(nowUtc);
  print('Now UTC: $nowUtc  | Using GFS cycle: $cycleUtc');

  // 2) Résout un chemin de sortie robuste à partir de l’emplacement du script
  final scriptDir = Directory.fromUri(Platform.script.resolve('.'));
  final outRoot = Directory('${scriptDir.path}repositories');
  if (!outRoot.existsSync()) {
    outRoot.createSync(recursive: true);
  }
  print('Output directory: ${outRoot.path}');

  // 3) Prépare le downloader
  final downloader = GribDownloader();

  // 4) Exemple: GFS 0.25° sur une bbox Ouest-Europe / Bretagne élargie
  //    Ajuste la bbox / jours / pas / variables à ta convenance.
  final opts = GribDownloadOptions(
    model: GribModel.gfs025,
    cycleUtc: cycleUtc,
    days: 2,                  // 1..7
    stepHours: 3,             // 1, 3, 6 … (selon dispo)
    leftLon: -12.0,
    rightLon: 12.0,
    bottomLat: 41.0,
    topLat: 52.0,
    variables: const [
      GribVariable.wind10m,
      GribVariable.windGust,
      GribVariable.mslp,
      GribVariable.precip,
      GribVariable.airTemp2m,
      // GribVariable.cloudTotal,
      // GribVariable.cape,
    ],
    outDir: outRoot,
  );

  // 5) Téléchargement
  print('Starting download…');
  final files = await downloader.download(opts);
  print('Downloaded ${files.length} files.');

  // 6) Listing final (nom + taille)
  if (files.isEmpty) {
    print('No files downloaded. Vérifie la connexion et les variables/échéances.');
  } else {
    print('Files saved:');
    for (final f in files) {
      final sizeKb = (await f.length()) / 1024.0;
      print(' - ${f.path}  (${sizeKb.toStringAsFixed(1)} KB)');
    }
  }

  // 7) EXTRAS (décommente pour tester vagues et courants/T° eau) :
  // await _testWavesWW3(downloader, cycleUtc, outRoot);
  // await _testRtofsOcean(downloader, cycleUtc, outRoot);

  print('=== Done ===');
}

/// Retourne le dernier cycle GFS disponible (00/06/12/18Z) <= nowUtc.
/// Si on est avant 00Z du jour, revient au 18Z de la veille.
DateTime _latestGfsCycleUtc(DateTime nowUtc) {
  const cycles = [0, 6, 12, 18];
  final hour = nowUtc.hour;
  int chosen = cycles.first;
  for (final c in cycles) {
    if (c <= hour) chosen = c;
  }
  final dt = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, chosen);
  if (dt.isAfter(nowUtc)) {
    // Sécurité : si dépasse (ne devrait pas arriver), recule d’1 jour sur 18Z
    final y = nowUtc.subtract(const Duration(days: 1));
    return DateTime.utc(y.year, y.month, y.day, 18);
  }
  return dt;
}

/// Test optionnel: vagues WW3 (Hs/Dir/Per)
Future<void> _testWavesWW3(
  GribDownloader downloader,
  DateTime cycleUtc,
  Directory outRoot,
) async {
  print('Testing WW3 waves…');
  final files = await downloader.download(
    GribDownloadOptions(
      model: GribModel.ww3Global,
      cycleUtc: cycleUtc,
      days: 1,
      stepHours: 3,
      leftLon: -12, rightLon: 12, bottomLat: 41, topLat: 52,
      variables: const [GribVariable.waves],
      outDir: outRoot,
    ),
  );
  print('[WW3] Downloaded ${files.length} files.');
}

/// Test optionnel: courants + T° eau (RTOFS)
Future<void> _testRtofsOcean(
  GribDownloader downloader,
  DateTime cycleUtc,
  Directory outRoot,
) async {
  print('Testing RTOFS ocean…');
  final files = await downloader.download(
    GribDownloadOptions(
      model: GribModel.rtofsGlobal,
      cycleUtc: DateTime.utc(cycleUtc.year, cycleUtc.month, cycleUtc.day, 0),
      days: 1,
      stepHours: 6,
      leftLon: -12, rightLon: 12, bottomLat: 41, topLat: 52,
      variables: const [GribVariable.current, GribVariable.seaTemp],
      outDir: outRoot,
    ),
  );
  print('[RTOFS] Downloaded ${files.length} files.');
}
