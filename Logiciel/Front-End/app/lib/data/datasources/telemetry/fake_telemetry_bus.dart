/// Simulated telemetry bus (wind/nav/env). 3-mode TWA model.
/// See ARCHITECTURE_DOCS.md (section: lib/data/datasources/telemetry/fake_telemetry_bus.dart).
// ------------------------------
import 'dart:async';
import 'dart:math' as math;
import 'package:kornog/common/utils/angle_utils.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_bus.dart';
import 'package:kornog/domain/entities/telemetry.dart';
import 'package:kornog/config/wind_test_config.dart';


/// Transposition d'un simulateur de vent inspiré de `Girouette_anemo_simu.py`.
/// Ici on centralise la production de TWD/TWS puis on dérive TWA/AWA.
enum TwaSimMode { irregular, rotatingLeft, rotatingRight }

class FakeTelemetryBus implements TelemetryBus {
	final TwaSimMode mode;
	final _snap$ = StreamController<TelemetrySnapshot>.broadcast();
	final Map<String, StreamController<Measurement>> _keyStreams = {};
	Timer? _timer;
	final _rng = math.Random();

	// ---------------- Wind Simulator (utilise WindTestConfig) ----------------
	double _baseTwd = WindTestConfig.baseDirection;
	double _elapsedMin = 0;
	final double _baseTws = WindTestConfig.baseSpeed;

	// --------------- Position Simulator ---------------
	// Position de départ (Baie de Morlaix, approximation)
	double _latitude = 48.6275;
	double _longitude = -3.9337;
	// Vitesse de déplacement simulée (environ 0.001 deg/sec = ~100m/sec drifting)
	static const double _latVelocity = 0.0000167; // ~1.8 m/s
	static const double _lonVelocity = 0.0000133; // ~1.4 m/s

	FakeTelemetryBus({this.mode = TwaSimMode.irregular}) {
		_start = DateTime.now();
		_timer = Timer.periodic(Duration(milliseconds: WindTestConfig.updateIntervalMs), (_) => _tick());
	}

	late DateTime _start;

	void _emit(String key, Measurement m, Map<String, Measurement> bucket) {
		bucket[key] = m;
		_keyStreams.putIfAbsent(key, () => StreamController<Measurement>.broadcast()).add(m);
	}

	void _tick() {
		final now = DateTime.now();
		_elapsedMin = DateTime.now().difference(_start).inSeconds / 60.0;

		// Heading stable arbitraire pour cohérence visuelle (ex: 90°)
		final hdg = 90.0;
		final sog = 6 + _rng.nextDouble() * 1.5;
		final cog = (hdg + _rng.nextDouble() * 4 - 2) % 360;

		// Update position simulée (drift graduel)
		_latitude += _latVelocity * (_rng.nextDouble() - 0.5) * 0.2;
		_longitude += _lonVelocity * (_rng.nextDouble() - 0.5) * 0.2;

		// Direction vent selon configuration et mode automatique
		double twd;
		TwaSimMode activeMode = _getActiveMode();
		
		switch (activeMode) {
			case TwaSimMode.irregular:
				final noise = _gaussian(stdDev: WindTestConfig.noiseMagnitude, clampAbs: WindTestConfig.oscillationAmplitude);
				twd = (_baseTwd + noise) % 360;
				break;
			case TwaSimMode.rotatingLeft:
			case TwaSimMode.rotatingRight:
				// Utilisation directe du rotationRate de la config (peut être positif ou négatif)
				final base = _baseTwd + WindTestConfig.rotationRate * _elapsedMin;
				final noise = _gaussian(stdDev: WindTestConfig.noiseMagnitude, clampAbs: WindTestConfig.oscillationAmplitude / 2);
				twd = (base + noise) % 360;
				break;
		}
		if (twd < 0) twd += 360;

		final tws = _baseTws + _gaussian(stdDev: 0.2, clampAbs: 0.5);
		// TWA signé: heading - TWD (positif si vent vient tribord). On utilise utilitaire.
		final twa = signedDelta(twd, hdg);
		final aws = tws + _rng.nextDouble() * 0.8 - 0.4;
		final awa = (twa + _rng.nextDouble() * 4 - 2).clamp(-180, 180).toDouble();
		
		// Debug des valeurs de vent
		print('DEBUG - TWD: ${twd.toStringAsFixed(1)}°, HDG: ${hdg.toStringAsFixed(1)}°, TWA: ${twa.toStringAsFixed(1)}°');

		final Map<String, Measurement> m = {};
		_emit('nav.sog', Measurement(value: sog, unit: Unit.knot, ts: now), m);
		_emit('nav.hdg', Measurement(value: hdg, unit: Unit.degree, ts: now), m);
		_emit('nav.cog', Measurement(value: cog, unit: Unit.degree, ts: now), m);
		// Position simulée
		_emit('nav.lat', Measurement(value: _latitude, unit: Unit.none, ts: now), m);
		_emit('nav.lon', Measurement(value: _longitude, unit: Unit.none, ts: now), m);

		_emit('wind.twd', Measurement(value: twd, unit: Unit.degree, ts: now), m);
		_emit('wind.tws', Measurement(value: tws, unit: Unit.knot, ts: now), m);
		_emit('wind.twa', Measurement(value: twa, unit: Unit.degree, ts: now), m);
		_emit('wind.aws', Measurement(value: aws, unit: Unit.knot, ts: now), m);
		_emit('wind.awa', Measurement(value: awa, unit: Unit.degree, ts: now), m);

		_emit('env.depth', Measurement(value: 20 + _rng.nextDouble() * 5, unit: Unit.meter, ts: now), m);
		_emit('env.waterTemp', Measurement(value: 18 + _rng.nextDouble() * 2, unit: Unit.celsius, ts: now), m);

		final snap = TelemetrySnapshot(ts: now, metrics: m);
		_snap$.add(snap);
	}

	/// Détermine le mode actuel selon la configuration WindTestConfig
	TwaSimMode _getActiveMode() {
		// Si le mode externe est défini, on l'utilise
		if (mode != TwaSimMode.irregular) return mode;
		
		// Sinon on se base sur la configuration de test
		switch (WindTestConfig.mode) {
			case 'stable':
			case 'irregular':
			case 'chaotic':
				return TwaSimMode.irregular;
			case 'backing_left':
				return TwaSimMode.rotatingLeft;
			case 'veering_right':
				return TwaSimMode.rotatingRight;
			default:
				return TwaSimMode.irregular;
		}
	}

	double _gaussian({double mean = 0, double stdDev = 1, double clampAbs = double.infinity}) {
		final u1 = (_rng.nextDouble().clamp(1e-9, 1.0));
		final u2 = _rng.nextDouble();
		final z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
		var v = mean + z0 * stdDev;
		if (v > clampAbs) v = clampAbs; if (v < -clampAbs) v = -clampAbs; return v;
	}




@override
Stream<TelemetrySnapshot> snapshots() => _snap$.stream;


@override
Stream<Measurement> watch(String key) =>
	_keyStreams.putIfAbsent(key, () => StreamController<Measurement>.broadcast()).stream;


void dispose() {
	_timer?.cancel();
	_snap$.close();
	for (final c in _keyStreams.values) { c.close(); }
}
}

// ---------------------------------------------------------------------------
// Wind simulator (ported from Girouette_anemo_simu.py logic)
// ---------------------------------------------------------------------------
// (Ancien simulateur détaillé supprimé : simplification autour d'un modèle 3 modes TWD)