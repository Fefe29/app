import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/geographic_position.dart';
import 'coordinate_system_provider.dart'; // CoordinateSystemConfig & LocalPosition

// Fallback: certaines versions de dart:math n'ont pas sinh/cosh/tanh
double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2.0;

class MercatorCoordinateSystemService {
  final CoordinateSystemConfig config;
  MercatorCoordinateSystemService({required this.config});

  // --- Local <-> Geographic --------------------------------------------------
  LocalPosition toLocal(GeographicPosition geo) {
    final o = config.origin;
    final lat0 = o.latitude * math.pi / 180.0;
    const metersPerDegLat = 111320.0;
    final metersPerDegLon = 111320.0 * math.cos(lat0);

    final dx = (geo.longitude - o.longitude) * metersPerDegLon; // Est +
    final dy = (geo.latitude  - o.latitude)  * metersPerDegLat; // Nord +
    return LocalPosition(x: dx, y: dy);
  }

  GeographicPosition toGeographic(LocalPosition local) {
    final o = config.origin;
    final lat0 = o.latitude * math.pi / 180.0;
    const metersPerDegLat = 111320.0;
    final metersPerDegLon = 111320.0 * math.cos(lat0);

    final dLat = local.y / metersPerDegLat;
    final dLon = local.x / metersPerDegLon;

    return GeographicPosition(
      latitude:  o.latitude  + dLat,
      longitude: o.longitude + dLon,
    );
  }

  // --- Web Mercator helpers --------------------------------------------------

  /// XYZ -> (lon, lat) du coin **NW** de la tuile (WGS84 deg).
  (double lonDeg, double latDeg) tileXYToLonLat(int x, int y, int z) {
    final n = math.pow(2, z).toDouble();
    final lonDeg = x / n * 360.0 - 180.0;
    final latRad = math.atan(_sinh(math.pi * (1.0 - 2.0 * (y / n))));
    final latDeg = latRad * 180.0 / math.pi;
    return (lonDeg, latDeg);
  }

  /// Coin d’une tuile en coordonnées **locales** (m).
  LocalPosition tileToLocal(int x, int y, int z) {
    final (lon, lat) = tileXYToLonLat(x, y, z);
    return toLocal(GeographicPosition(latitude: lat, longitude: lon));
  }

  /// Bounds locaux (NW et SE) d’une tuile (x,y,z).
  (LocalPosition nw, LocalPosition se) tileBoundsLocal(int x, int y, int z) {
    final nw = tileToLocal(x, y, z);
    final se = tileToLocal(x + 1, y + 1, z);
    return (nw, se);
  }
}

// Provider

class MercatorCoordinateSystemNotifier extends Notifier<MercatorCoordinateSystemService> {
  @override
  MercatorCoordinateSystemService build() {
    return MercatorCoordinateSystemService(
      config: CoordinateSystemConfig(
        name: 'MercatorLocal',
        origin: const GeographicPosition(latitude: 43.5350, longitude: 6.9990),
      ),
    );
  }

  /// Permet de changer dynamiquement l'origine du système de coordonnées
  void setOrigin(GeographicPosition newOrigin) {
    state = MercatorCoordinateSystemService(
      config: CoordinateSystemConfig(
        name: state.config.name,
        origin: newOrigin,
      ),
    );
  }
}

final mercatorCoordinateSystemProvider =
    NotifierProvider<MercatorCoordinateSystemNotifier, MercatorCoordinateSystemService>(
      MercatorCoordinateSystemNotifier.new,
    );
