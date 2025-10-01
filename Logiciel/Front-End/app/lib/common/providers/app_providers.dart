// ------------------------------
// File: lib/providers.dart
// ------------------------------
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_bus.dart';
import 'package:kornog/data/datasources/telemetry/fake_telemetry_bus.dart';
import 'package:kornog/domain/entities/telemetry.dart';


final telemetryBusProvider = Provider<TelemetryBus>((ref) {
final bus = FakeTelemetryBus();
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