/// Other (Depth & Wind) alarms provider.
/// Handles: shallow depth, wind shift, wind drop, wind raise.
/// Listens to telemetry metrics via existing metricProvider keys:
///   env.depth, wind.twd, wind.tws
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'package:kornog/common/utils/angle_utils.dart';
import 'package:kornog/domain/entities/telemetry.dart';
import 'package:kornog/common/providers/app_providers.dart';

// Individual alarm slices -------------------------------------------------

class DepthAlarmState {
  final bool enabled;
  final double minDepthMeters;
  final bool triggered;
  final double? lastDepth;
  const DepthAlarmState({
    required this.enabled,
    required this.minDepthMeters,
    required this.triggered,
    this.lastDepth,
  });
  DepthAlarmState copyWith({bool? enabled, double? minDepthMeters, bool? triggered, double? lastDepth}) => DepthAlarmState(
        enabled: enabled ?? this.enabled,
        minDepthMeters: minDepthMeters ?? this.minDepthMeters,
        triggered: triggered ?? this.triggered,
        lastDepth: lastDepth ?? this.lastDepth,
      );
}

class WindShiftAlarmState {
  final bool enabled;
  final double thresholdDeg; // trigger when absolute delta >= threshold
  final bool triggered;
  final double? baselineDir; // captured when enabling / recalibrating
  final double? currentDiffAbs;
  const WindShiftAlarmState({
    required this.enabled,
    required this.thresholdDeg,
    required this.triggered,
    this.baselineDir,
    this.currentDiffAbs,
  });
  WindShiftAlarmState copyWith({
    bool? enabled,
    double? thresholdDeg,
    bool? triggered,
    double? baselineDir,
    double? currentDiffAbs,
  }) => WindShiftAlarmState(
        enabled: enabled ?? this.enabled,
        thresholdDeg: thresholdDeg ?? this.thresholdDeg,
        triggered: triggered ?? this.triggered,
        baselineDir: baselineDir ?? this.baselineDir,
        currentDiffAbs: currentDiffAbs ?? this.currentDiffAbs,
      );
}

class WindThresholdAlarmState {
  final bool enabled;
  final double threshold; // knots
  final bool triggered;
  final double? lastValue;
  const WindThresholdAlarmState({
    required this.enabled,
    required this.threshold,
    required this.triggered,
    this.lastValue,
  });
  WindThresholdAlarmState copyWith({bool? enabled, double? threshold, bool? triggered, double? lastValue}) => WindThresholdAlarmState(
        enabled: enabled ?? this.enabled,
        threshold: threshold ?? this.threshold,
        triggered: triggered ?? this.triggered,
        lastValue: lastValue ?? this.lastValue,
      );
}

// Composite state ---------------------------------------------------------

class OtherAlarmsState {
  final DepthAlarmState depth;
  final WindShiftAlarmState windShift;
  final WindThresholdAlarmState windDrop; // triggers when TWS < threshold
  final WindThresholdAlarmState windRaise; // triggers when TWS > threshold
  const OtherAlarmsState({
    required this.depth,
    required this.windShift,
    required this.windDrop,
    required this.windRaise,
  });
  OtherAlarmsState copyWith({
    DepthAlarmState? depth,
    WindShiftAlarmState? windShift,
    WindThresholdAlarmState? windDrop,
    WindThresholdAlarmState? windRaise,
  }) => OtherAlarmsState(
        depth: depth ?? this.depth,
        windShift: windShift ?? this.windShift,
        windDrop: windDrop ?? this.windDrop,
        windRaise: windRaise ?? this.windRaise,
      );
}

class OtherAlarmsNotifier extends Notifier<OtherAlarmsState> {
  @override
  OtherAlarmsState build() {
    // Listen to metrics
    ref.listen(metricProvider('env.depth'), (prev, next) {
      next.whenOrNull(data: (m) => _onDepth(m));
    });
    ref.listen(metricProvider('wind.twd'), (prev, next) {
      next.whenOrNull(data: (m) => _onWindDir(m));
    });
    ref.listen(metricProvider('wind.tws'), (prev, next) {
      next.whenOrNull(data: (m) => _onWindSpeed(m));
    });
    return OtherAlarmsState(
      depth: const DepthAlarmState(enabled: false, minDepthMeters: 5, triggered: false),
      windShift: const WindShiftAlarmState(enabled: false, thresholdDeg: 15, triggered: false),
      windDrop: const WindThresholdAlarmState(enabled: false, threshold: 4, triggered: false),
      windRaise: const WindThresholdAlarmState(enabled: false, threshold: 25, triggered: false),
    );
  }

  void toggleDepth(bool v) => state = state.copyWith(depth: state.depth.copyWith(enabled: v, triggered: v ? state.depth.triggered : false));
  void setMinDepth(double d) => state = state.copyWith(depth: state.depth.copyWith(minDepthMeters: d));
  void resetDepthAlarm() => state = state.copyWith(depth: state.depth.copyWith(triggered: false));

  void toggleWindShift(bool v, {double? currentDir}) => state = state.copyWith(
        windShift: state.windShift.copyWith(
          enabled: v,
          triggered: v ? state.windShift.triggered : false,
          baselineDir: v ? (currentDir ?? state.windShift.baselineDir) : state.windShift.baselineDir,
        ),
      );
  void setWindShiftThreshold(double deg) => state = state.copyWith(windShift: state.windShift.copyWith(thresholdDeg: deg));
  void recalibrateShift(double currentDir) => state = state.copyWith(windShift: state.windShift.copyWith(baselineDir: currentDir, triggered: false, currentDiffAbs: 0));
  void resetShift() => state = state.copyWith(windShift: state.windShift.copyWith(triggered: false));

  void toggleWindDrop(bool v) => state = state.copyWith(windDrop: state.windDrop.copyWith(enabled: v, triggered: v ? state.windDrop.triggered : false));
  void setWindDropThreshold(double vKn) => state = state.copyWith(windDrop: state.windDrop.copyWith(threshold: vKn));
  void resetWindDrop() => state = state.copyWith(windDrop: state.windDrop.copyWith(triggered: false));

  void toggleWindRaise(bool v) => state = state.copyWith(windRaise: state.windRaise.copyWith(enabled: v, triggered: v ? state.windRaise.triggered : false));
  void setWindRaiseThreshold(double vKn) => state = state.copyWith(windRaise: state.windRaise.copyWith(threshold: vKn));
  void resetWindRaise() => state = state.copyWith(windRaise: state.windRaise.copyWith(triggered: false));

  // Internal metric reactions -------------------------------------------
  void _onDepth(Measurement m) {
    if (!state.depth.enabled) return;
    final shallow = m.value < state.depth.minDepthMeters;
    if (shallow && !state.depth.triggered) {
      state = state.copyWith(depth: state.depth.copyWith(triggered: true, lastDepth: m.value));
    } else {
      state = state.copyWith(depth: state.depth.copyWith(lastDepth: m.value));
    }
  }

  void _onWindDir(Measurement m) {
    final ws = state.windShift;
    if (!ws.enabled) return;
    final baseline = ws.baselineDir ?? m.value;
    final diff = _angleDiffAbs(baseline, m.value);
    final triggered = diff >= ws.thresholdDeg;
    state = state.copyWith(
      windShift: ws.copyWith(
        baselineDir: baseline,
        currentDiffAbs: diff,
        triggered: ws.triggered || triggered,
      ),
    );
  }

  void _onWindSpeed(Measurement m) {
    // Drop
    if (state.windDrop.enabled) {
      final dropTrig = m.value < state.windDrop.threshold;
      if (dropTrig && !state.windDrop.triggered) {
        state = state.copyWith(windDrop: state.windDrop.copyWith(triggered: true, lastValue: m.value));
      } else {
        state = state.copyWith(windDrop: state.windDrop.copyWith(lastValue: m.value));
      }
    }
    // Raise
    if (state.windRaise.enabled) {
      final raiseTrig = m.value > state.windRaise.threshold;
      if (raiseTrig && !state.windRaise.triggered) {
        state = state.copyWith(windRaise: state.windRaise.copyWith(triggered: true, lastValue: m.value));
      } else {
        state = state.copyWith(windRaise: state.windRaise.copyWith(lastValue: m.value));
      }
    }
  }

  double _angleDiffAbs(double a, double b) => absDelta(a, b);
}

final otherAlarmsProvider = NotifierProvider<OtherAlarmsNotifier, OtherAlarmsState>(OtherAlarmsNotifier.new);
