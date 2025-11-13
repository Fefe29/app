/// Widget pour afficher la position et l'orientation du bateau sur la cartographie
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/providers/app_providers.dart';
import '../../../../data/datasources/telemetry/telemetry_bus.dart';
import '../../../../domain/entities/telemetry.dart';
import '../../providers/mercator_coordinate_system_provider.dart';
import '../../domain/models/geographic_position.dart';
import '../models/view_transform.dart';

/// Painter pour dessiner le bateau
class _BoatPainter extends CustomPainter {
  _BoatPainter({
    required this.boatPosition,
    required this.heading,
    required this.mercatorService,
    required this.view,
    this.boatSize = 24.0,
    this.boatColor = Colors.purple,
  });

  final GeographicPosition? boatPosition;
  final double? heading; // Degrés (0 = Nord, 90 = Est)
  final MercatorCoordinateSystemService mercatorService;
  final ViewTransform view;
  final double boatSize;
  final Color boatColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (boatPosition == null) return;

    // Convertir la position GPS en coordonnées locales Mercator
    final localPos = mercatorService.toLocal(boatPosition!);
    
    // Projeter sur le canvas
    final boatPixel = view.project(localPos.x, localPos.y, size);

    // Vérifier que le bateau est visible dans le viewport
    if (boatPixel.dx < -50 || boatPixel.dx > size.width + 50 ||
        boatPixel.dy < -50 || boatPixel.dy > size.height + 50) {
      return; // Bateau hors écran, ne pas dessiner
    }

    // Dessiner le bateau
    _drawBoat(canvas, boatPixel, heading ?? 0.0);
  }

  void _drawBoat(Canvas canvas, Offset position, double headingDeg) {
    // Convertir le cap en radians (0° = haut, 90° = droite en trigonométrie mais 90° = Est)
    // Pour Flutter: 0° en haut, angles horaires
    final angleRad = (headingDeg - 90) * math.pi / 180.0;

    // ========== DESIGN AMÉLIORÉ - VOILIER RÉALISTE ==========
    
    // Vecteur de direction (vers le cap)
    final frontX = math.cos(angleRad);
    final frontY = math.sin(angleRad);
    
    // Vecteur perpendiculaire (tribord)
    final orthoX = -math.sin(angleRad);
    final orthoY = math.cos(angleRad);

    // Dimensions du bateau (en pixels)
    final boatLength = boatSize * 2.2;      // Longueur totale
    final boatWidth = boatSize * 0.5;        // Largeur max (au maître)
    final cockpitSize = boatSize * 0.4;      // Taille cockpit

    // ===== COQUE (Hull) =====
    final hullPath = Path();
    
    // Proa (avant pointu)
    final proaX = position.dx + frontX * boatLength * 0.45;
    final proaY = position.dy + frontY * boatLength * 0.45;
    
    // Points de la coque (profil de navire)
    final p1 = Offset(proaX, proaY);                                                    // Proa
    final p2 = Offset(position.dx + frontX * boatLength * 0.15 + orthoX * boatWidth, 
                      position.dy + frontY * boatLength * 0.15 + orthoY * boatWidth);   // Maître tribord
    final p3 = Offset(position.dx + frontX * -boatLength * 0.35 + orthoX * boatWidth * 0.6, 
                      position.dy + frontY * -boatLength * 0.35 + orthoY * boatWidth * 0.6);  // Arrière tribord
    final p4 = Offset(position.dx + frontX * -boatLength * 0.35, 
                      position.dy + frontY * -boatLength * 0.35);                       // Centre arrière
    final p5 = Offset(position.dx + frontX * -boatLength * 0.35 - orthoX * boatWidth * 0.6, 
                      position.dy + frontY * -boatLength * 0.35 - orthoY * boatWidth * 0.6);  // Arrière bâbord
    final p6 = Offset(position.dx + frontX * 0.15 - orthoX * boatWidth, 
                      position.dy + frontY * 0.15 - orthoY * boatWidth);                // Maître bâbord

    hullPath
      ..moveTo(p1.dx, p1.dy)
      ..quadraticBezierTo(p2.dx, p2.dy, p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..lineTo(p5.dx, p5.dy)
      ..quadraticBezierTo(p6.dx, p6.dy, p1.dx, p1.dy)
      ..close();

    // Remplissage de la coque (violet)
    final hullFill = Paint()
      ..color = boatColor.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(hullPath, hullFill);

    // Bordure de la coque
    final hullStroke = Paint()
      ..color = boatColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(hullPath, hullStroke);

    // ===== COCKPIT (Habitacle) =====
    final cockpitCenter = Offset(
      position.dx + frontX * boatLength * -0.05,
      position.dy + frontY * boatLength * -0.05,
    );
    final cockpitPath = Path();
    final cockpitH = cockpitSize * 0.8;
    final cockpitW = cockpitSize * 0.4;
    
    cockpitPath
      ..moveTo(cockpitCenter.dx + frontX * cockpitH, cockpitCenter.dy + frontY * cockpitH)
      ..lineTo(cockpitCenter.dx + orthoX * cockpitW + frontX * -cockpitH * 0.3, 
               cockpitCenter.dy + orthoY * cockpitW + frontY * -cockpitH * 0.3)
      ..lineTo(cockpitCenter.dx - orthoX * cockpitW + frontX * -cockpitH * 0.3, 
               cockpitCenter.dy - orthoY * cockpitW + frontY * -cockpitH * 0.3)
      ..close();

    final cockpitFill = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawPath(cockpitPath, cockpitFill);

    final cockpitStroke = Paint()
      ..color = boatColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(cockpitPath, cockpitStroke);

    // ===== MÂTURE (Mast) =====
    final mastTop = Offset(
      position.dx + frontX * boatLength * 0.05,
      position.dy + frontY * boatLength * 0.05,
    );
    
    final mastStroke = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(position, mastTop, mastStroke);

    // ===== LIGNE DE PROA (étrave) =====
    final proaLine = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final proaEndX = position.dx + frontX * boatLength * 0.25;
    final proaEndY = position.dy + frontY * boatLength * 0.25;
    canvas.drawLine(position, Offset(proaEndX, proaEndY), proaLine);

    // ===== LIGNE ROUGE DE CAP =====
    final capLineLength = boatSize * 3.0;
    final capLineEnd = Offset(
      position.dx + frontX * capLineLength,
      position.dy + frontY * capLineLength,
    );
    
    final capLine = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(position, capLineEnd, capLine);

    // ===== TEXTE DU CAP =====
    final headingText = '${headingDeg.toStringAsFixed(0)}°';
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: headingText,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Positionner le texte au-dessus de la ligne de cap
    final textOffset = Offset(
      position.dx + frontX * (capLineLength * 0.5) - textPainter.width / 2,
      position.dy + frontY * (capLineLength * 0.5) - textPainter.height - 4,
    );
    
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(_BoatPainter oldDelegate) {
    return oldDelegate.boatPosition != boatPosition ||
        oldDelegate.heading != heading ||
        oldDelegate.view != view;
  }

  @override
  bool shouldRebuildSemantics(_BoatPainter oldDelegate) => false;
}

/// Widget pour afficher le bateau
class BoatIndicator extends ConsumerWidget {
  const BoatIndicator({
    super.key,
    required this.view,
    required this.canvasSize,
    required this.mercatorService,
    this.boatSize = 24.0,
    this.boatColor = Colors.purple,
  });

  final ViewTransform view;
  final Size canvasSize;
  final MercatorCoordinateSystemService mercatorService;
  final double boatSize;
  final Color boatColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observe la source de télémétrie
    final telemetryBus = ref.watch(telemetryBusProvider);

    // Écouter le stream de snapshots pour obtenir les positions et heading en temps réel
    return StreamBuilder<TelemetrySnapshot>(
      stream: telemetryBus.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final snapshotData = snapshot.data!;
        
        // Extraire les coordonnées et le cap du snapshot
        final latMeasure = snapshotData.metrics['nav.lat'];
        final lonMeasure = snapshotData.metrics['nav.lon'];
        final hdgMeasure = snapshotData.metrics['nav.hdg'];

        if (latMeasure == null || lonMeasure == null) {
          return const SizedBox.shrink();
        }

        final position = GeographicPosition(
          latitude: latMeasure.value,
          longitude: lonMeasure.value,
        );
        final heading = (hdgMeasure?.value) ?? 0.0;

        return RepaintBoundary(
          child: CustomPaint(
            size: canvasSize,
            painter: _BoatPainter(
              boatPosition: position,
              heading: heading,
              mercatorService: mercatorService,
              view: view,
              boatSize: boatSize,
              boatColor: boatColor,
            ),
          ),
        );
      },
    );
  }
}
