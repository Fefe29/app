/// Debug helper pour comprendre les différences de projection
import 'dart:math' as math;
import '../models/geographic_position.dart';
import '../../providers/coordinate_system_provider.dart';

class ProjectionDebugger {
  static void compareProjections(
    GeographicPosition geoPos,
    CoordinateSystemService coordService,
    int tileX,
    int tileY,
    int zoom,
  ) {
    print('=== PROJECTION DEBUG ===');
    print('Position géographique: ${geoPos.latitude}°, ${geoPos.longitude}°');
    
    // Méthode bouées (actuelle)
    final localBuoy = coordService.toLocal(geoPos);
    print('Projection bouées: x=${localBuoy.x.toStringAsFixed(2)}m, y=${localBuoy.y.toStringAsFixed(2)}m');
    
    // Méthode tuiles OSM
    final n = 1 << zoom;
    final tileGeoLon = tileX / n * 360.0 - 180.0;
    final tileGeoLatRad = math.atan((math.exp(math.pi * (1 - 2 * tileY / n)) - math.exp(-math.pi * (1 - 2 * tileY / n))) / 2);
    final tileGeoLat = tileGeoLatRad * 180.0 / math.pi;
    print('Position tuile convertie: ${tileGeoLat}°, ${tileGeoLon}°');
    
    // Différence
    final diffLat = (geoPos.latitude - tileGeoLat) * 111320; // en mètres
    final diffLon = (geoPos.longitude - tileGeoLon) * 111320 * math.cos(geoPos.latitude * math.pi / 180);
    print('Différence: ${diffLat.toStringAsFixed(2)}m lat, ${diffLon.toStringAsFixed(2)}m lon');
    print('========================');
  }
}