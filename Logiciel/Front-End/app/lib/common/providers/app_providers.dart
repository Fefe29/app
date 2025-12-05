/// Global providers (telemetry bus, wind sample, simulation mode).
/// See ARCHITECTURE_DOCS.md (section: lib/common/providers/app_providers.dart).
// ------------------------------
// File: lib/providers.dart
// ------------------------------
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kornog/data/datasources/telemetry/telemetry_bus.dart';
import 'package:kornog/domain/entities/telemetry.dart';
import 'package:kornog/data/datasources/telemetry/fake_telemetry_bus.dart'; // contains TwaSimMode & FakeTelemetryBus
import 'package:kornog/data/datasources/telemetry/network_telemetry_bus.dart';
import 'package:kornog/config/telemetry_config.dart';
import 'package:kornog/common/providers/telemetry_providers.dart';
import 'package:kornog/common/providers/nmea_stream_provider.dart';


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
	final sourceModeAsync = ref.watch(telemetrySourceModeProvider);
	final networkConfig = ref.watch(telemetryNetworkConfigProvider);
	
	// Gérer AsyncValue de sourceMode - utiliser maybeWhen pour extraire la valeur
	final mode = sourceModeAsync.maybeWhen(
		data: (m) {
			// ignore: avoid_print
			print('🔄 TelemetryBusProvider: sourceMode.data = $m');
			return m;
		},
		orElse: () {
			// ignore: avoid_print
			print('🔄 TelemetryBusProvider: sourceMode non prête, utilisant defaut');
			return defaultTelemetrySourceMode;
		},
	);
	
	// ignore: avoid_print
	print('🔄 TelemetryBusProvider recalcul: mode=$mode, networkEnabled=${networkConfig.enabled}');
	
	if (mode == TelemetrySourceMode.network && networkConfig.enabled) {
		// Mode réseau : tenter de créer NetworkTelemetryBus
		try {
			final networkBus = NetworkTelemetryBus(
				config: NetworkConfig(
					host: networkConfig.host,
					port: networkConfig.port,
				),
			);
			// Initialiser connexion de manière asynchrone (sans attendre)
			networkBus.connect();
			
			// Écouter le stream NMEA et alimenter le notifier
			// (sans bloquer cette fonction)
			Future.microtask(() {
				// ignore: avoid_print
				print('📡 Démarrage de l\'écoute du stream NMEA...');
				final subscription = networkBus.nmeaFrames().listen(
					(frame) {
						// ignore: avoid_print
						print('🎯 Trame NMEA reçue: ${frame.raw}');
						try {
							ref
								.read(nmeaSentencesProvider.notifier)
								.addSentence(frame.raw, isValid: frame.isValid, error: frame.errorMessage);
							// ignore: avoid_print
							print('✅ Trame ajoutée au notifier');
						} catch (e) {
							// ignore: avoid_print
							print('❌ Erreur ajout trame: $e');
						}
					},
					onError: (error) {
						// ignore: avoid_print
						print('❌ Erreur stream NMEA: $error');
					},
					onDone: () {
						// ignore: avoid_print
						print('⚠️ Stream NMEA fermé');
					},
				);
				// Garder la subscription active
				ref.onDispose(() => subscription.cancel());
			});
			
			ref.onDispose(() => networkBus.dispose());
			// ignore: avoid_print
			print('🌐 TelemetryBus: Mode RÉSEAU activé');
			return networkBus;
		} catch (e) {
			// ignore: avoid_print
			print('❌ Erreur création NetworkTelemetryBus: $e, basculage vers FakeTelemetryBus');
		}
	}

	// Mode simulation (par défaut ou fallback)
	final simMode = ref.watch(twaSimModeProvider);
	final bus = FakeTelemetryBus(mode: simMode);
	ref.onDispose(() => bus.dispose());
	// ignore: avoid_print
	print('🎮 TelemetryBus: Mode SIMULATION activé');
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