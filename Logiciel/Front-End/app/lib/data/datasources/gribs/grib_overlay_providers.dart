import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grib_overlay_models.dart';

/// --- GRILLE COURANTE (ScalarGrid?) ---
class CurrentGribGridNotifier extends Notifier<ScalarGrid?> {
  @override
  ScalarGrid? build() => null;

  void setGrid(ScalarGrid? grid) => state = grid;
  void clear() => state = null;
}

final currentGribGridProvider =
    NotifierProvider<CurrentGribGridNotifier, ScalarGrid?>(CurrentGribGridNotifier.new);

/// --- OPACITÉ (double 0..1) ---
class GribOpacityNotifier extends Notifier<double> {
  @override
  double build() => 0.6;
  void set(double v) => state = v.clamp(0.0, 1.0);
}

final gribOpacityProvider =
    NotifierProvider<GribOpacityNotifier, double>(GribOpacityNotifier.new);

/// --- VMINS / VMAX (bornes palette) ---
class GribVminNotifier extends Notifier<double> {
  @override
  double build() => 0.0;
  void set(double v) => state = v;
}
final gribVminProvider =
    NotifierProvider<GribVminNotifier, double>(GribVminNotifier.new);

class GribVmaxNotifier extends Notifier<double> {
  @override
  double build() => 25.0;
  void set(double v) => state = v;
}
final gribVmaxProvider =
    NotifierProvider<GribVmaxNotifier, double>(GribVmaxNotifier.new);
