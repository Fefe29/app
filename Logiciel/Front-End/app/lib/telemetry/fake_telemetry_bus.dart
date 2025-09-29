// ------------------------------
import 'dart:async';
import 'dart:math';
import 'telemetry_bus.dart';
import 'telemetry_models.dart';


class FakeTelemetryBus implements TelemetryBus {
final _snap$ = StreamController<TelemetrySnapshot>.broadcast();
final Map<String, StreamController<Measurement>> _keyStreams = {};
Timer? _timer; final _rng = Random();


FakeTelemetryBus() {
_timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
final now = DateTime.now();
final Map<String, Measurement> m = {
'nav.sog': Measurement(value: 6 + _rng.nextDouble() * 2, unit: Unit.knot, ts: now),
'nav.cog': Measurement(value: _rng.nextDouble() * 360, unit: Unit.degree, ts: now),
'wind.twa': Measurement(value: -45 + _rng.nextDouble() * 90, unit: Unit.degree, ts: now),
'wind.tws': Measurement(value: 10 + _rng.nextDouble() * 8, unit: Unit.knot, ts: now),
'wind.awa': Measurement(value: -30 + _rng.nextDouble() * 60, unit: Unit.degree, ts: now),
'wind.aws': Measurement(value: 12 + _rng.nextDouble() * 5, unit: Unit.knot, ts: now),
'nav.hdg': Measurement(value: _rng.nextDouble() * 360, unit: Unit.degree, ts: now),
'env.depth': Measurement(value: 20 + _rng.nextDouble() * 5, unit: Unit.meter, ts: now),
'env.waterTemp': Measurement(value: 18 + _rng.nextDouble() * 2, unit: Unit.celsius, ts: now),
};
final snap = TelemetrySnapshot(ts: now, metrics: m);
_snap$.add(snap);
// push per-key
for (final e in m.entries) {
_keyStreams.putIfAbsent(e.key, () => StreamController.broadcast());
_keyStreams[e.key]!.add(e.value);
}
});
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