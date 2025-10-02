/// Angle utilities.
/// Base convention: absolute bearings in [0,360) where 0 = North, 90 = East.
/// Signed deltas are only used for relative comparisons (e.g. TWA, wind shift) and
/// always returned in [-180,180]. Keep all storage & transport values absolute when possible.
library angle_utils;

import 'dart:math' as math;

/// Normalize any angle (deg) into [0,360).
double norm360(num a) {
  final v = a % 360;
  return v < 0 ? v + 360 : v.toDouble();
}

/// Smallest signed delta to go from `fromDeg` -> `toDeg` (result in [-180,180]).
/// Example: signedDelta(350, 10) = +20 ; signedDelta(10, 350) = -20.
/// This matches typical sailing TWA style when you pass (windDir, heading).
double signedDelta(num fromDeg, num toDeg) {
  return ((toDeg - fromDeg + 540) % 360) - 180;
}

/// Absolute angular difference (0..180).
double absDelta(num a, num b) => signedDelta(a, b).abs();

/// Compute geographic bearing from a 2D vector.
/// Coordinate frames:
/// - If [screenYAxisDown] = true (Flutter canvas style): +X = East, +Y = Down (South).
///   Geographic north = negative Y, so bearing = atan2(dx, -dy).
/// - If [screenYAxisDown] = false (math classical): +X = East, +Y = North.
///   Bearing = atan2(dx, dy).
/// Returns angle in [0,360).
double bearingFromVector(double dx, double dy, {bool screenYAxisDown = true}) {
  double rad;
  if (screenYAxisDown) {
    rad = math.atan2(dx, -dy);
  } else {
    rad = math.atan2(dx, dy); // y already north-positive
  }
  return norm360(rad * 180 / math.pi);
}

/// Build a unit vector (dx, dy) from a geographic bearing.
/// In screen coordinates (Y down) returns (sin, -cos) so that 0° points up.
math.Point<double> vectorFromBearing(double bearingDeg, {bool screenYAxisDown = true}) {
  final r = bearingDeg * math.pi / 180;
  if (screenYAxisDown) {
    return math.Point(math.sin(r), -math.cos(r));
  } else {
    return math.Point(math.sin(r), math.cos(r));
  }
}

/// Convert a signed relative angle (e.g. TWA) back to an absolute bearing
/// given a reference direction (e.g. wind FROM direction) using the convention:
/// signed = heading - reference (normalized to [-180,180]).
/// So: heading = reference + signedDelta then normalized.
double bearingFromSignedOffset(num reference, num signed) => norm360(reference + signed);
