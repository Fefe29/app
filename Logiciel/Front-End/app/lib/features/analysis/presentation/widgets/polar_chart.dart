import 'package:flutter/material.dart';
import 'dart:math';

/// Représente les données polaires :
/// polaires[forceVent] = [vitesse pour chaque angle]
class PolarChart extends StatelessWidget {
  final Map<int, List<double>> polaires; // ex: {6: [...], 8: [...], ...}
  final List<double> angles; // ex: [30, 35, ..., 150]
  final int? selectedWindForce; // null = toutes
  final int? currentWindForce; // pour highlight

  const PolarChart({
    required this.polaires,
    required this.angles,
    this.selectedWindForce,
    this.currentWindForce,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _PolarChartPainter(
          polaires: polaires,
          angles: angles,
          selectedWindForce: selectedWindForce,
          currentWindForce: currentWindForce,
        ),
        child: Container(),
      ),
    );
  }
}

class _PolarChartPainter extends CustomPainter {
  final Map<int, List<double>> polaires;
  final List<double> angles;
  final int? selectedWindForce;
  final int? currentWindForce;

  _PolarChartPainter({
    required this.polaires,
    required this.angles,
    this.selectedWindForce,
    this.currentWindForce,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.85;
    final paintGrid = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke;

    // Dessine les cercles de vitesse
    for (double v = 2; v <= 12; v += 2) {
      canvas.drawCircle(center, v / 12 * radius, paintGrid);
    }
    // Dessine les rayons d'angle
    for (var a in angles) {
      final rad = (a - 90) * pi / 180;
      final p = Offset(center.dx + cos(rad) * radius, center.dy + sin(rad) * radius);
      canvas.drawLine(center, p, paintGrid);
    }

    // Couleurs pour chaque force de vent
    final colors = [Colors.blue, Colors.green, Colors.pink, Colors.red, Colors.brown, Colors.black];
    int colorIdx = 0;

    // Sélectionne les courbes à afficher
    final toShow = selectedWindForce != null
      ? [selectedWindForce!]
      : polaires.keys.toList();

    for (var force in toShow) {
      final speeds = polaires[force]!;
      final path = Path();
      for (int i = 0; i < angles.length; i++) {
        final angle = angles[i];
        final speed = speeds[i];
        final rad = (angle - 90) * pi / 180;
        final r = speed / 12 * radius;
        final pt = Offset(center.dx + cos(rad) * r, center.dy + sin(rad) * r);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      final paintCurve = Paint()
        ..color = (currentWindForce == force) ? Colors.orange : colors[colorIdx % colors.length]
        ..strokeWidth = (currentWindForce == force) ? 3 : 2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paintCurve);
      colorIdx++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
