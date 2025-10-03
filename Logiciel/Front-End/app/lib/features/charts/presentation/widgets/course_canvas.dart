/// Custom painter widget for course & wind depiction.
/// See ARCHITECTURE_DOCS.md (section: course_canvas.dart).
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../charts/providers/course_providers.dart';
import '../../domain/models/course.dart';
import '../../../charts/providers/route_plan_provider.dart';
import '../../../charts/domain/services/routing_calculator.dart';
import 'package:kornog/common/providers/app_providers.dart';
import '../../../charts/providers/polar_providers.dart';
import '../../../charts/providers/wind_trend_provider.dart';
import '../../../charts/domain/services/wind_trend_analyzer.dart';

/// Widget displaying the course (buoys + start/finish lines) in plan view.
class CourseCanvas extends ConsumerWidget {
  const CourseCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  final course = ref.watch(courseProvider);
  final route = ref.watch(routePlanProvider);
  final wind = ref.watch(windSampleProvider);
  final vmcUp = ref.watch(vmcUpwindProvider); // Pour laylines (angle optimal de près)
  final windTrend = ref.watch(windTrendSnapshotProvider); // Analyse des tendances de vent
    if (course.buoys.isEmpty && course.startLine == null && course.finishLine == null) {
      return const Center(child: Text('Aucune bouée / ligne'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return RepaintBoundary(
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _CoursePainter(
              course,
              route,
              wind.directionDeg,
              wind.speed,
              vmcUp?.angleDeg,
              windTrend,
            ),
          ),
        );
      },
    );
  }
}

class _CoursePainter extends CustomPainter {
  _CoursePainter(
    this.state,
    this.route,
    this.windDirDeg,
    this.windSpeed,
    this.upwindOptimalAngle,
    this.windTrend,
  );
  final CourseState state;
  final RoutePlan route;
  final double windDirDeg; // 0 = Nord (haut), 90 = Est (droite)
  final double windSpeed; // nds
  final double? upwindOptimalAngle; // angle (°) par rapport au vent pour meilleure VMG près
  final WindTrendSnapshot windTrend; // Analyse des tendances de vent

  static const double margin = 24.0; // logical px margin inside canvas
  static const double buoyRadius = 8.0;

  late final _Bounds _bounds = _computeBounds();

  _Bounds _computeBounds() {
    final xs = <double>[];
    final ys = <double>[];
    for (final b in state.buoys) {
      xs..add(b.x);
      ys..add(b.y);
    }
    for (final l in [state.startLine, state.finishLine]) {
      if (l != null) {
        xs..add(l.p1x)..add(l.p2x);
        ys..add(l.p1y)..add(l.p2y);
      }
    }
    if (xs.isEmpty || ys.isEmpty) {
      return const _Bounds(0, 100, 0, 100); // default square
    }
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    // Guard against zero span
    var spanX = (maxX - minX).abs() < 1e-6 ? 100 : maxX - minX;
    var spanY = (maxY - minY).abs() < 1e-6 ? 100 : maxY - minY;

    // Pour assurer une échelle cohérente (1:1), on force la bounding box à être carrée.
    if (spanX > spanY) {
      final delta = spanX - spanY;
      // Étendre Y de part et d'autre pour rester centré
      return _Bounds(minX, minX + spanX, minY - delta / 2, minY + spanY + delta / 2);
    } else if (spanY > spanX) {
      final delta = spanY - spanX;
      return _Bounds(minX - delta / 2, minX + spanX + delta / 2, minY, minY + spanY);
    }
    return _Bounds(minX, minX + spanX, minY, minY + spanY);
  }

  Offset _project(double x, double y, Size size) {
    // Nous voulons un facteur d'échelle unique pour X et Y afin de conserver les angles.
    final availW = size.width - 2 * margin;
    final availH = size.height - 2 * margin;
    final spanX = _bounds.maxX - _bounds.minX;
    final spanY = _bounds.maxY - _bounds.minY;
    final scale = math.min(availW / spanX, availH / spanY);
    // Centrage si l'espace disponible n'est pas carré
    final offsetX = (size.width - spanX * scale) / 2;
    final offsetY = (size.height - spanY * scale) / 2;
    final px = offsetX + (x - _bounds.minX) * scale;
    // y croissant vers le haut dans notre repère logique -> inverser
    final py = size.height - offsetY - (y - _bounds.minY) * scale;
    return Offset(px, py);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = Colors.blueGrey.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bg);

    _drawGrid(canvas, size);

    _drawLines(canvas, size);
    _drawRoute(canvas, size);
    _drawBuoys(canvas, size);
    _drawWind(canvas, size);
    _drawLaylines(canvas, size);
    _drawWindTrendInfo(canvas, size);
    _drawBoundsInfo(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    const gridStep = 50.0; // logical units after projection (approx)
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    // We'll draw an approximate grid in screen space every 60 px
    for (double x = margin; x < size.width - margin; x += 60) {
      canvas.drawLine(Offset(x, margin), Offset(x, size.height - margin), paint);
    }
    for (double y = margin; y < size.height - margin; y += 60) {
      canvas.drawLine(Offset(margin, y), Offset(size.width - margin, y), paint);
    }
  }

  void _drawLines(Canvas canvas, Size size) {
    for (final line in [state.startLine, state.finishLine]) {
      if (line == null) continue;
      final p1 = _project(line.p1x, line.p1y, size);
      final p2 = _project(line.p2x, line.p2y, size);
      final paint = Paint()
        ..strokeWidth = line.type == LineType.start ? 4 : 3
        ..style = PaintingStyle.stroke
        ..color = line.type == LineType.start ? Colors.greenAccent.shade400 : Colors.redAccent.shade400;
      canvas.drawLine(p1, p2, paint);
      // Label at midpoint
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawText(
        canvas,
        line.type == LineType.start ? 'Start' : 'Finish',
        mid + const Offset(4, -16),
        color: paint.color,
        fontSize: 12,
      );
    }
  }

  void _drawBuoys(Canvas canvas, Size size) {
    for (final b in state.buoys) {
      final p = _project(b.x, b.y, size);
      final colors = _colorsForRole(b.role);
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = colors.background;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.border;
      canvas.drawCircle(p, buoyRadius, fill);
      canvas.drawCircle(p, buoyRadius, stroke);
      final label = _labelForBuoy(b);
      _drawText(canvas, label, p + const Offset(10, -4), fontSize: 11, color: colors.text);
    }
  }

  void _drawRoute(Canvas canvas, Size size) {
    if (route.isEmpty) return;
    final pathPaint = Paint()
      ..color = Colors.cyanAccent.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final leg in route.legs) {
      final p1 = _project(leg.startX, leg.startY, size);
      final p2 = _project(leg.endX, leg.endY, size);
      canvas.drawLine(p1, p2, pathPaint);
      // Optionnel : petit marqueur
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawText(canvas, _shortLabel(leg), mid + const Offset(4, -10), fontSize: 10, color: Colors.cyan.shade900);
    }
  }

  void _drawWind(Canvas canvas, Size size) {
    // Flèche montrant la direction VERS laquelle souffle le vent (sens inverse de la provenance).
    // Direction FROM = windDirDeg. Direction TO = windDirDeg + 180°.
    const arrowLen = 70.0;
    final toDir = (windDirDeg + 180.0) % 360.0;
    final angleRad = toDir * math.pi / 180.0;
    // Vecteur écran (0°=Nord => vers le haut => y négatif) donc : x=sin, y=-cos
    final vx = math.sin(angleRad);
    final vy = -math.cos(angleRad);

    final base = Offset(size.width - margin - arrowLen * 0.2, margin + 10);
    final tip = base + Offset(vx, vy) * arrowLen;

    final shaft = Paint()
      ..color = Colors.indigo.shade400
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, tip, shaft);

    // Triangle tête pointant vers la DESTINATION du vent.
    final headSize = 12.0;
    final ortho = Offset(-vy, vx);
    final headP1 = tip;
    final headP2 = tip - Offset(vx, vy) * headSize + ortho * (headSize * 0.6);
    final headP3 = tip - Offset(vx, vy) * headSize - ortho * (headSize * 0.6);
    final headPath = Path()
      ..moveTo(headP1.dx, headP1.dy)
      ..lineTo(headP2.dx, headP2.dy)
      ..lineTo(headP3.dx, headP3.dy)
      ..close();
    final headPaint = Paint()
      ..color = Colors.indigo.shade300
      ..style = PaintingStyle.fill;
    canvas.drawPath(headPath, headPaint);
    canvas.drawPath(headPath, shaft);

    final label = 'Vent→  from ${windDirDeg.toStringAsFixed(0)}°  ${windSpeed.toStringAsFixed(1)} nds';
    _drawText(canvas, label, base + const Offset(-210, 8), fontSize: 12, color: Colors.indigo.shade700);
  }

  void _drawLaylines(Canvas canvas, Size size) {
    if (upwindOptimalAngle == null) return;
    // Origine : première bouée régulière (bouée au vent pour les laylines), sinon centre bounding box
    double ox;
    double oy;
    
    // Chercher la première bouée régulière (par ordre de passage)
    final regularBuoys = state.buoys.where((b) => b.role == BuoyRole.regular).toList();
    if (regularBuoys.isNotEmpty) {
      // Trier par passageOrder puis par id
      regularBuoys.sort((a, b) {
        final ao = a.passageOrder;
        final bo = b.passageOrder;
        if (ao != null && bo != null) {
          final c = ao.compareTo(bo);
          if (c != 0) return c;
        } else if (ao != null) {
          return -1;
        } else if (bo != null) {
          return 1;
        }
        return a.id.compareTo(b.id);
      });
      
      final firstBuoy = regularBuoys.first;
      ox = firstBuoy.x;
      oy = firstBuoy.y;
    } else if (state.buoys.isNotEmpty) {
      final first = state.buoys.first;
      ox = first.x;
      oy = first.y;
    } else {
      // centre des bounds
      ox = (_bounds.minX + _bounds.maxX) / 2;
      oy = (_bounds.minY + _bounds.maxY) / 2;
    }

  // windDirDeg représente la DIRECTION D'OU PROVIENT le vent (FROM). Pour remonter au vent,
  // les laylines montrent la DIRECTION DE NAVIGATION du bateau (cap + 180° par rapport au vent).
  // Caps de navigation au près = (windDirDeg + 180°) +/- upwindOptimalAngle.
  final heading1 = (windDirDeg + 180.0 - upwindOptimalAngle!) % 360.0; // tack bâbord 
  final heading2 = (windDirDeg + 180.0 + upwindOptimalAngle!) % 360.0; // tack tribord

    final maxSpan = math.max(_bounds.maxX - _bounds.minX, _bounds.maxY - _bounds.minY);
    final length = maxSpan * 1.2; // un peu plus grand que le terrain

    void drawLay(double headingDeg, Color color, String side) {
      final rad = headingDeg * math.pi / 180.0;
      // Convertir heading (0=N) en vecteur coordonnées logiques (Y vers le haut) : x=sin, y=cos
      final vx = math.sin(rad);
      final vy = math.cos(rad);
      final ex = ox + vx * length;
      final ey = oy + vy * length;
      final p1 = _project(ox, oy, size);
      final p2 = _project(ex, ey, size);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      // Trait en pointillés léger
      const dash = 10.0;
      const gap = 6.0;
      final total = (p2 - p1).distance;
      final dir = (p2 - p1) / total;
      double dist = 0;
      while (dist < total) {
        final s = p1 + dir * dist;
        final e = p1 + dir * math.min(dist + dash, total);
        canvas.drawLine(s, e, paint);
        dist += dash + gap;
      }
      
      // Afficher l'angle de la layline
      final midPoint = p1 + dir * (total * 0.6); // Position à 60% de la ligne
      final displayAngle = (headingDeg + 180) % 360;
      _drawText(
        canvas,
        '${displayAngle.toStringAsFixed(0)}° $side',
        midPoint + const Offset(5, -10),
        fontSize: 10,
        color: color.withOpacity(0.9),
      );
    }

    drawLay(heading1, Colors.lightGreenAccent.shade400, 'Bb');  // Bâbord
    drawLay(heading2, Colors.lightGreenAccent.shade700, 'Tb');  // Tribord
  }

  String _shortLabel(RouteLeg leg) {
    switch (leg.type) {
      case RouteLegType.start:
        return 'Départ';
      case RouteLegType.finish:
        return 'Arrivée';
      case RouteLegType.leg:
      default:
        return leg.label ?? '';
    }
  }

  _RoleColors _colorsForRole(BuoyRole role) {
    switch (role) {
      case BuoyRole.committee:
        return _RoleColors(
          background: Colors.white,
          border: Colors.blueGrey.shade800,
          text: Colors.blueGrey.shade900,
        );
      case BuoyRole.target:
        return _RoleColors(
          background: Colors.purpleAccent.shade100,
          border: Colors.purple.shade700,
          text: Colors.purple.shade900,
        );
      case BuoyRole.regular:
      default:
        return _RoleColors(
          background: Colors.amber.shade400,
          border: Colors.orange.shade700,
          text: Colors.black87,
        );
    }
  }

  String _labelForBuoy(Buoy b) {
    switch (b.role) {
      case BuoyRole.committee:
        return 'Com';
      case BuoyRole.target:
        return 'Vis';
      case BuoyRole.regular:
      default:
        final base = 'B${b.id}';
        if (b.passageOrder != null) return '$base(${b.passageOrder})';
        return base;
    }
  }

  void _drawWindTrendInfo(Canvas canvas, Size size) {
    // Affichage dans le coin supérieur gauche
    const margin = 12.0;
    const lineHeight = 16.0;
    
    // Couleur et style selon la tendance détectée
    Color trendColor;
    String trendIcon;
    String trendLabel;
    
    switch (windTrend.trend) {
      case WindTrendDirection.veeringRight:
        trendColor = Colors.green.shade700;
        trendIcon = '↗';
        trendLabel = 'BASCULE DROITE';
        break;
      case WindTrendDirection.backingLeft:
        trendColor = Colors.orange.shade700;
        trendIcon = '↙';
        trendLabel = 'BASCULE GAUCHE';
        break;
      case WindTrendDirection.irregular:
        trendColor = Colors.red.shade600;
        trendIcon = '≋';
        trendLabel = 'IRRÉGULIER';
        break;
      case WindTrendDirection.neutral:
        trendColor = Colors.blue.shade600;
        trendIcon = '→';
        trendLabel = 'STABLE';
        break;
    }
    
    // Fond semi-transparent
    final background = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    const boxWidth = 180.0;
    const boxHeight = 70.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(margin, margin, boxWidth, boxHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, background);
    
    // Titre
    _drawText(
      canvas, 
      '📊 ANALYSE VENT',
      const Offset(margin + 8, margin + 8),
      fontSize: 11,
      color: Colors.white70,
    );
    
    // Tendance principale avec icône
    _drawText(
      canvas,
      '$trendIcon $trendLabel',
      const Offset(margin + 8, margin + 8 + lineHeight),
      fontSize: 13,
      color: trendColor,
    );
    
    // Pente et fiabilité
    final slopeText = windTrend.linearSlopeDegPerMin >= 0 
        ? '+${windTrend.linearSlopeDegPerMin.toStringAsFixed(1)}°/min'
        : '${windTrend.linearSlopeDegPerMin.toStringAsFixed(1)}°/min';
    
    _drawText(
      canvas,
      'Pente: $slopeText',
      const Offset(margin + 8, margin + 8 + lineHeight * 2),
      fontSize: 10,
      color: Colors.white70,
    );
    
    // Fiabilité
    final reliability = windTrend.isReliable ? '✓ Fiable' : '⚠ Peu fiable';
    final reliabilityColor = windTrend.isReliable ? Colors.green.shade400 : Colors.orange.shade400;
    
    _drawText(
      canvas,
      '$reliability (${windTrend.supportPoints}pts)',
      const Offset(margin + 8, margin + 8 + lineHeight * 3),
      fontSize: 10,
      color: reliabilityColor,
    );
  }

  void _drawBoundsInfo(Canvas canvas, Size size) {
    final txt = 'X:[${_bounds.minX.toStringAsFixed(1)} ; ${_bounds.maxX.toStringAsFixed(1)}]  '
        'Y:[${_bounds.minY.toStringAsFixed(1)} ; ${_bounds.maxY.toStringAsFixed(1)}]';
    _drawText(canvas, txt, Offset(8, size.height - 18), fontSize: 11, color: Colors.blueGrey);
  }

  void _drawText(Canvas canvas, String text, Offset position, {double fontSize = 14, Color color = Colors.black}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _CoursePainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.route != route ||
        oldDelegate.windDirDeg != windDirDeg ||
        oldDelegate.windSpeed != windSpeed ||
        oldDelegate.upwindOptimalAngle != upwindOptimalAngle ||
        oldDelegate.windTrend != windTrend;
  }
}

class _Bounds {
  const _Bounds(this.minX, this.maxX, this.minY, this.maxY);
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}

class _RoleColors {
  const _RoleColors({required this.background, required this.border, required this.text});
  final Color background;
  final Color border;
  final Color text;
}
