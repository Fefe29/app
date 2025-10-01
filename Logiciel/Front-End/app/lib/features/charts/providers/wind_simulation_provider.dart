import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/common/providers/app_providers.dart';

class WindSample {
  WindSample({required this.directionDeg, required this.speed});
  final double directionDeg; // 0..360 (FROM direction)
  final double speed; // nds (TWS approx)
}

/// Modes internes de simulation du vent.
/// - irregular: bruit gaussien autour de l'angle initial (±10° clamp) sans dérive.
/// - rotatingLeft: rotation continue -2°/min + bruit gaussien (±6° clamp).
/// - rotatingRight: rotation continue +2°/min + bruit gaussien (±6° clamp).
enum WindSimMode { irregular, rotatingLeft, rotatingRight }

class WindSimulationModeNotifier extends Notifier<WindSimMode> {
  @override
  WindSimMode build() => WindSimMode.irregular; // mode par défaut
  void setMode(WindSimMode m) => state = m;
}

final windSimulationModeProvider = NotifierProvider<WindSimulationModeNotifier, WindSimMode>(
  WindSimulationModeNotifier.new,
);

class _WindSimNotifier extends Notifier<WindSample> {
  static const double _initialDir = 0.0; // demandé: initialement 0°
  static const double _baseSpeed = 7.0; // vitesse de base arbitraire
  static const double _rotRateDegPerMin = 2.0; // ±2° par minute selon mode

  Timer? _timer;
  late DateTime _start;
  final math.Random _rng = math.Random();

  double _gaussian({double mean = 0, double stdDev = 1, double clampAbs = double.infinity}) {
    // Box-Muller
    final u1 = (_rng.nextDouble().clamp(1e-9, 1.0));
    final u2 = _rng.nextDouble();
    final z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
    var v = mean + z0 * stdDev;
    if (v > clampAbs) v = clampAbs;
    if (v < -clampAbs) v = -clampAbs;
    return v;
  }

  @override
  WindSample build() {
    _start = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final mode = ref.read(windSimulationModeProvider);
      final elapsedSec = DateTime.now().difference(_start).inSeconds;
      final elapsedMin = elapsedSec / 60.0;

      double dirDeg;
      switch (mode) {
        case WindSimMode.irregular:
          // Bruit gaussien clampé ±10° autour de l'angle initial (non cumulatif)
            final noise = _gaussian(stdDev: 4, clampAbs: 10); // écart-type 4° approx
          dirDeg = (_initialDir + noise) % 360;
          break;
        case WindSimMode.rotatingLeft:
          final base = _initialDir - _rotRateDegPerMin * elapsedMin; // rotation lente négative
          final noise = _gaussian(stdDev: 2, clampAbs: 6); // bruit instantané ±6°
          dirDeg = (base + noise) % 360;
          break;
        case WindSimMode.rotatingRight:
          final base = _initialDir + _rotRateDegPerMin * elapsedMin; // rotation lente positive
          final noise = _gaussian(stdDev: 2, clampAbs: 6);
          dirDeg = (base + noise) % 360;
          break;
      }

      if (dirDeg < 0) dirDeg += 360;

      // Vitesse : on peut ajouter un léger bruit (±0.3 nds) pour vivacité.
      final speed = _baseSpeed + _gaussian(stdDev: 0.15, clampAbs: 0.3);
      state = WindSample(directionDeg: dirDeg, speed: speed);
    });
    ref.onDispose(() => _timer?.cancel());
    return WindSample(directionDeg: _initialDir, speed: _baseSpeed);
  }
}

final windSimulationProvider = NotifierProvider<_WindSimNotifier, WindSample>(_WindSimNotifier.new);

// ---------------------------------------------------------------------------
// Unified wind provider: if real (or fake telemetry) provides wind.twd & wind.tws
// we map those; otherwise we fallback to the internal simulator above.
// This lets the dashboard and the charts share a single consistent wind source.
// ---------------------------------------------------------------------------

final unifiedWindProvider = Provider<WindSample>((ref) {
  // Try snapshot stream latest value
  final snapAsync = ref.watch(snapshotStreamProvider);
  return snapAsync.maybeWhen(
    data: (snap) {
      final twd = snap.metrics['wind.twd']?.value; // true wind direction (FROM)
      final tws = snap.metrics['wind.tws']?.value; // true wind speed
      if (twd != null && tws != null) {
        return WindSample(directionDeg: twd % 360, speed: tws);
      }
      // fallback: derive twd from cog + twa if available: twd = (cog - twa) modulo 360
      final cog = snap.metrics['nav.cog']?.value; // course over ground
      final twa = snap.metrics['wind.twa']?.value; // signed angle (bâbord négatif / tribord positif)
      if (cog != null && twa != null) {
        final derivedTwd = (cog - twa) % 360;
        final tws2 = tws ?? snap.metrics['wind.aws']?.value ?? 8.0;
        return WindSample(directionDeg: derivedTwd, speed: tws2);
      }
      // final fallback: use simulator
      return ref.watch(windSimulationProvider);
    },
    orElse: () => ref.watch(windSimulationProvider),
  );
});