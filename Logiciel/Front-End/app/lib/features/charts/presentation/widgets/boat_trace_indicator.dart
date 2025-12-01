/// Widget pour afficher la trace du bateau (historique de la trajectoire)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/geographic_position.dart';
import '../models/view_transform.dart';
import '../../providers/mercator_coordinate_system_provider.dart';
import '../../providers/boat_trace_provider.dart';

class BoatTraceIndicator extends ConsumerWidget {
  const BoatTraceIndicator({
    super.key,
    required this.view,
    required this.canvasSize,
    required this.mercatorService,
    this.traceColor = const Color(0xFFFF6B6B),
    this.traceWidth = 2.0,
  });

  final ViewTransform view;
  final Size canvasSize;
  final MercatorCoordinateSystemService mercatorService;
  final Color traceColor;
  final double traceWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observe la trace du bateau
    final trace = ref.watch(boatTraceProvider);

    if (trace.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: CustomPaint(
        size: canvasSize,
        painter: _TracePainter(
          trace: trace,
          mercatorService: mercatorService,
          view: view,
          traceColor: traceColor,
          traceWidth: traceWidth,
        ),
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.trace,
    required this.mercatorService,
    required this.view,
    required this.traceColor,
    required this.traceWidth,
  });

  final List<GeographicPosition> trace;
  final MercatorCoordinateSystemService mercatorService;
  final ViewTransform view;
  final Color traceColor;
  final double traceWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (trace.length < 2) return;

    final paint = Paint()
      ..color = traceColor
      ..strokeWidth = traceWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final points = <Offset>[];
    for (final pos in trace) {
      try {
        final localPos = mercatorService.toLocal(pos);
        final screenPos = view.project(localPos.x, localPos.y, size);
        points.add(screenPos);
      } catch (e) {
        // Ignorer les erreurs de projection
      }
    }

    if (points.length < 2) return;

    // Dessiner la polyline
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) {
    return oldDelegate.trace.length != trace.length ||
        oldDelegate.view.scale != view.scale ||
        oldDelegate.view.offsetX != view.offsetX ||
        oldDelegate.view.offsetY != view.offsetY ||
        oldDelegate.view.minX != view.minX ||
        oldDelegate.view.maxX != view.maxX ||
        oldDelegate.view.minY != view.minY ||
        oldDelegate.view.maxY != view.maxY;
  }
}
