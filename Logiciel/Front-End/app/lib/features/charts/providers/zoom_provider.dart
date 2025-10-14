import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the current zoom level (1.0 = 100%)
final zoomProvider = NotifierProvider<ZoomNotifier, double>(ZoomNotifier.new);

class ZoomNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void setZoom(double zoom) => state = zoom.clamp(0.2, 5.0);
  void zoomIn() => setZoom(state * 1.2);
  void zoomOut() => setZoom(state / 1.2);
}
