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
	// Position de départ (Rade de Brest, décalée 300m à l'est)
	double _latitude = 48.369485;
	double _longitude = -4.480326; // 300m à l'est de -4.483626
	
	// Simulation d'aller-retour entre la ligne de départ et la bouée 1
	// Bouée 1: 48.369485°N, -4.483626°W (au vent)
	// Viseur (ligne départ): 48.3614850°N, -4.4714260°W
	static const double _buoy1Lat = 48.369485;
	static const double _buoy1Lon = -4.483626;
	static const double _startLineLat = 48.3614850;
	static const double _startLineLon = -4.4714260;
	
	double _elapsedTime = 0; // Temps écoulé en secondes
	double _currentHeading = 90.0; // Cap actuel du bateau
	static const double _oscillationPeriod = 480.0; // Période d'aller-retour en secondes (8 minutes pour mouvement très lent)
	static const double _boatSpeed = 3.0; // Vitesse du bateau en nœuds (~1.5 m/s)

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
		_elapsedTime += WindTestConfig.updateIntervalMs / 1000.0; // Convertir en secondes

		// ========== SIMULATION D'ALLER-RETOUR ==========
		// Calculer la phase d'oscillation (entre 0 et 1, puis revenir)
		final phase = (_elapsedTime % _oscillationPeriod) / _oscillationPeriod;
		
		// Interpolation linéaire entre deux points
		// phase [0, 0.5] : aller vers bouée 1
		// phase [0.5, 1] : retour vers ligne départ
		double interpolationFactor;
		if (phase < 0.5) {
			// Aller vers bouée 1
			interpolationFactor = phase * 2.0; // [0, 1]
		} else {
			// Retour vers ligne départ
			interpolationFactor = (1.0 - phase) * 2.0; // [1, 0]
		}
		
		// Positionner le bateau entre la ligne de départ et la bouée 1
		_latitude = _startLineLat + (_buoy1Lat - _startLineLat) * interpolationFactor;
		_longitude = _startLineLon + (_buoy1Lon - _startLineLon) * interpolationFactor;
		
		// ========== CALCUL DU CAP ==========
		// Calculer le vecteur de direction
		double targetHeading;
		if (phase < 0.5) {
			// En allant vers la bouée 1 (Nord-Ouest)
			targetHeading = _calculateHeading(_startLineLat, _startLineLon, _buoy1Lat, _buoy1Lon);
		} else {
			// En revenant vers la ligne de départ (Sud-Est)
			targetHeading = _calculateHeading(_buoy1Lat, _buoy1Lon, _startLineLat, _startLineLon);
		}
		
		// Lissage du cap avec une petite variation pour réalisme
		_currentHeading = targetHeading + (_rng.nextDouble() * 2 - 1);
		if (_currentHeading < 0) _currentHeading += 360;
		if (_currentHeading >= 360) _currentHeading -= 360;
		
		final hdg = _currentHeading;
		final sog = _boatSpeed + _rng.nextDouble() * 0.5 - 0.25;
		final cog = (hdg + _rng.nextDouble() * 4 - 2) % 360;

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

	/// Calcule le cap (heading) entre deux points géographiques
	/// Retourne un angle en degrés (0° = Nord, 90° = Est, 180° = Sud, 270° = Ouest)
	double _calculateHeading(double fromLat, double fromLon, double toLat, double toLon) {
		// Différences en latitude et longitude
		double dLat = toLat - fromLat;
		double dLon = toLon - fromLon;
		
		// Calcul du cap initial (en radians)
		// Formule: cap = atan2(dLon, dLat) convertie pour système géographique
		double headingRad = math.atan2(dLon, dLat);
		
		// Convertir en degrés
		double headingDeg = headingRad * 180.0 / math.pi;
		
		// Normaliser entre 0 et 360
		if (headingDeg < 0) headingDeg += 360;
		if (headingDeg >= 360) headingDeg -= 360;
		
		return headingDeg;
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