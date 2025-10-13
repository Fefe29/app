import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mapview/services/geo_service.dart';
import '../../../features/charts/providers/course_providers.dart';
import 'dart:ui';

class VectorLayer extends ConsumerWidget {
  const VectorLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseProvider);
    final geo = GeoService();
    return CustomPaint(
      painter: _VectorPainter(course, geo),
      isComplex: true,
      willChange: true,
      child: const SizedBox.expand(),
    );
  }
}

class _VectorPainter extends CustomPainter {
  _VectorPainter(this.course, this.geo);
  final dynamic course; // ton type concret
  final GeoService geo;

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Récupère centre+zoom/viewport depuis tes providers map si besoin
    // 2) Pour chaque bouée: projeter WGS84 -> 3857 -> pixels => dessiner
    // 3) Pour laylines/routes: idem, tracer des Path
  }

  @override
  bool shouldRepaint(covariant _VectorPainter oldDelegate) => course != oldDelegate.course;
}
