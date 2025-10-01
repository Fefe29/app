// ------------------------------
// File: lib/telemetry/telemetry_models.dart
// ------------------------------
class Unit {
final String symbol;
const Unit(this.symbol);
static const knot = Unit('kn');
static const degree = Unit('°');
static const meter = Unit('m');
static const celsius = Unit('°C');
static const none = Unit('');
}


class Measurement {
final double value;
final Unit unit;
final DateTime ts;
const Measurement({required this.value, required this.unit, required this.ts});
}


/// A protocol-agnostic telemetry snapshot:
/// key => measurement (e.g. "nav.sog" => 6.4 kn)
class TelemetrySnapshot {
final DateTime ts;
final Map<String, Measurement> metrics; // dotted keys
final Map<String, Object?> tags; // optional contextual tags (e.g. source, boatId)
const TelemetrySnapshot({required this.ts, required this.metrics, this.tags = const {}});
}