// ------------------------------
// File: lib/providers.dart
// ------------------------------
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:kornog/data/datasources/telemetry/telemetry_bus.dart';
import 'package:kornog/domain/entities/telemetry.dart';
import 'package:kornog/features/charts/providers/wind_simulation_provider.dart';


/// Bus de télémétrie de développement composite :
/// - Génère des métriques navigation/générales pseudo-aléatoires.
/// - Injecte le vent depuis `unifiedWindProvider` (modes contrôlés) au lieu du vent aléatoire précédent.
// ---------------------------------------------------------------------------
// Wind unified providers (déplacés ici pour éviter cycle d'import)
// ---------------------------------------------------------------------------
class _UseTelemetryWind extends Notifier<bool> {
	@override
	bool build() => false; // OFF par défaut
	void set(bool v) => state = v;
}

final useTelemetryWindProvider = NotifierProvider<_UseTelemetryWind, bool>(_UseTelemetryWind.new);

final Provider<WindSample> unifiedWindProvider = Provider<WindSample>((ref) {
	final useTelemetry = ref.watch(useTelemetryWindProvider);
	if (!useTelemetry) return ref.watch(windSimulationProvider);
	// Si on active télémétrie on lit les snapshots (extraction TWD/TWS) sinon fallback
	final snapAsync = ref.watch(snapshotStreamProvider);
	return snapAsync.maybeWhen(
		data: (snap) {
			final twd = snap.metrics['wind.twd']?.value;
			final tws = snap.metrics['wind.tws']?.value;
			if (twd != null && tws != null) {
				return WindSample(directionDeg: twd % 360, speed: tws);
			}
			return ref.watch(windSimulationProvider);
		},
		orElse: () => ref.watch(windSimulationProvider),
	);
});

class DevCompositeTelemetryBus implements TelemetryBus {
	DevCompositeTelemetryBus({required this.windGetter}) {
		_timer = Timer.periodic(const Duration(seconds: 1), _tick);
	}

	final WindSample Function() windGetter;
	final _snap$ = StreamController<TelemetrySnapshot>.broadcast();
	final Map<String, StreamController<Measurement>> _keyStreams = {};
	final _rng = math.Random();
	Timer? _timer;

	void _emitMeasurement(Map<String, Measurement> bucket, String key, Measurement m) {
		bucket[key] = m;
		_keyStreams.putIfAbsent(key, () => StreamController.broadcast()).add(m);
	}

	void _tick(Timer _) {
		final now = DateTime.now();
		final wind = windGetter();

		// Génération nav de base
		final sog = 6 + _rng.nextDouble() * 1.5; // 6 - 7.5 nds
		final hdg = _rng.nextDouble() * 360; // cap instantané arbitraire (on pourrait lisser plus tard)
		final cog = (hdg + _rng.nextDouble() * 6 - 3) % 360; // dérive légère

		// Calcul TWD/TWS déjà fournis par wind
		final twd = wind.directionDeg; // FROM
		final tws = wind.speed;
		// Déduire un TWA signé (-180..180) relative au heading (approx)
		double twa = ((twd - hdg + 540) % 360) - 180; // signé
		// Apparent: simplification (on met un petit écart bruité)
		final aws = tws + _rng.nextDouble() * 0.8 - 0.4;
		final awa = (twa + _rng.nextDouble() * 4 - 2).clamp(-180, 180).toDouble();

		final map = <String, Measurement>{};
		_emitMeasurement(map, 'nav.sog', Measurement(value: sog, unit: Unit.knot, ts: now));
		_emitMeasurement(map, 'nav.hdg', Measurement(value: hdg, unit: Unit.degree, ts: now));
		_emitMeasurement(map, 'nav.cog', Measurement(value: cog, unit: Unit.degree, ts: now));

		_emitMeasurement(map, 'wind.twd', Measurement(value: twd, unit: Unit.degree, ts: now));
		_emitMeasurement(map, 'wind.tws', Measurement(value: tws, unit: Unit.knot, ts: now));
		_emitMeasurement(map, 'wind.twa', Measurement(value: twa, unit: Unit.degree, ts: now));
		_emitMeasurement(map, 'wind.aws', Measurement(value: aws, unit: Unit.knot, ts: now));
		_emitMeasurement(map, 'wind.awa', Measurement(value: awa, unit: Unit.degree, ts: now));

		// Environnement
		_emitMeasurement(map, 'env.depth', Measurement(value: 18 + _rng.nextDouble() * 3, unit: Unit.meter, ts: now));
		_emitMeasurement(map, 'env.waterTemp', Measurement(value: 17.5 + _rng.nextDouble() * 1.5, unit: Unit.celsius, ts: now));

		final snap = TelemetrySnapshot(ts: now, metrics: map);
		_snap$.add(snap);
	}

	@override
	Stream<TelemetrySnapshot> snapshots() => _snap$.stream;

	@override
	Stream<Measurement> watch(String key) => _keyStreams.putIfAbsent(key, () => StreamController.broadcast()).stream;

	void dispose() {
		_timer?.cancel();
		_snap$.close();
		for (final c in _keyStreams.values) { c.close(); }
	}
}

final Provider<TelemetryBus> telemetryBusProvider = Provider<TelemetryBus>((ref) {
	// IMPORTANT: on utilise directement le simulateur de vent basique pour éviter un cycle.
	final bus = DevCompositeTelemetryBus(windGetter: () => ref.read(windSimulationProvider));
	ref.onDispose(() => bus.dispose());
	return bus;
});


/// Stream of full snapshots
final snapshotStreamProvider = StreamProvider.autoDispose((ref) {
final bus = ref.watch(telemetryBusProvider);
return bus.snapshots();
});


/// Helper to watch a single metric key
final metricProvider = StreamProvider.family.autoDispose<Measurement, String>((ref, key) {
final bus = ref.watch(telemetryBusProvider);
return bus.watch(key);
});