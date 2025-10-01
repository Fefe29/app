// ------------------------------
// File: lib/telemetry/telemetry_bus.dart (interface)
// ------------------------------
import 'dart:async';
import 'package:kornog/domain/entities/telemetry.dart';


abstract class TelemetryBus {
/// Stream of snapshots (useful for batch UI like dashboards)
Stream<TelemetrySnapshot> snapshots();


/// Watch a single metric key as a convenience (e.g. "nav.sog")
Stream<Measurement> watch(String key);
}