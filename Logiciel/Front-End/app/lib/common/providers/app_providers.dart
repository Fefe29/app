// ------------------------------
// File: lib/providers.dart
// ------------------------------
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:kornog/data/datasources/telemetry/telemetry_bus.dart';
import 'package:kornog/domain/entities/telemetry.dart';
import 'package:kornog/data/datasources/telemetry/fake_telemetry_bus.dart'; // contains TwaSimMode & FakeTelemetryBus


/// Bus + émulation centralisée : toutes les métriques (y compris vent) naissent ici.
// ---------------------------------------------------------------------------
// Wind unified providers (déplacés ici pour éviter cycle d'import)
// ---------------------------------------------------------------------------
// Émulation vent intégrée centralisée (vent réel futur: remplacer par un bus réseau)

class WindSample {
	WindSample({required this.directionDeg, required this.speed});
	final double directionDeg; // FROM 0..360
	final double speed; // TWS nds
}

// Notifier pour piloter le mode de simulation TWA
class TwaSimModeNotifier extends Notifier<TwaSimMode> {
	@override
	TwaSimMode build() => TwaSimMode.irregular;
	void setMode(TwaSimMode m) => state = m;
}

final twaSimModeProvider = NotifierProvider<TwaSimModeNotifier, TwaSimMode>(TwaSimModeNotifier.new);

// (Un futur flag pourra être réintroduit pour basculer vers une source réseau réelle.)

final Provider<TelemetryBus> telemetryBusProvider = Provider<TelemetryBus>((ref) {
	final mode = ref.watch(twaSimModeProvider);
	final bus = FakeTelemetryBus(mode: mode);
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

/// Provider reconstruisant un WindSample à partir des métriques émises.
final windSampleProvider = Provider<WindSample>((ref) {
	final snapAsync = ref.watch(snapshotStreamProvider);
	return snapAsync.maybeWhen(
		data: (snap) {
			final twd = snap.metrics['wind.twd']?.value;
			final tws = snap.metrics['wind.tws']?.value;
			if (twd != null && tws != null) {
				return WindSample(directionDeg: twd % 360, speed: tws);
			}
			return WindSample(directionDeg: 0, speed: 0);
		},
		orElse: () => WindSample(directionDeg: 0, speed: 0),
	);
});