import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../../charts/domain/models/geographic_position.dart';

class GeoService {
  static const double _R = 6378137.0; // sphère Web Mercator

  /// WGS84 -> Web Mercator (mètres projetés)
  Offset project3857(GeographicPosition gp) {
    final x = _R * gp.longitude * math.pi / 180.0;
    final y = _R * math.log(math.tan((math.pi / 4) + (gp.latitude * math.pi / 360)));
    return Offset(x, y);
  }

  /// Web Mercator -> WGS84
  GeographicPosition unproject3857(Offset xy) {
    final lon = (xy.dx / _R) * 180.0 / math.pi;
    final lat = (2 * math.atan(math.exp(xy.dy / _R)) - math.pi / 2) * 180.0 / math.pi;
    return GeographicPosition(latitude: lat, longitude: lon);
  }

  /// Repère local métrique approximatif (origine = origin)
  Offset toLocal(GeographicPosition origin, GeographicPosition target) {
    final lat1 = origin.latitude * math.pi / 180;
    final lat2 = target.latitude * math.pi / 180;
    final dLat = (target.latitude - origin.latitude) * math.pi / 180;
    final dLon = (target.longitude - origin.longitude) * math.pi / 180;

    final mx = dLon * math.cos((lat1 + lat2) / 2) * _R;
    final my = dLat * _R;
    return Offset(mx, my);
  }
}
