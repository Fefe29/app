import 'dart:math' as math;
import 'dart:typed_data';
import 'grib_models.dart';

/// Crée des grilles GRIB de test pour développement/debugging
class GribTestDataGenerator {
  /// Génère une grille GRIB synthétique pour tester
  /// Simule un champ de vent réaliste basé sur la position géographique
  static ScalarGrid generateTestWindGrid({
    String fieldName = 'UGRD:10 m',
    double minLon = -10.0,
    double maxLon = 10.0,
    double minLat = 40.0,
    double maxLat = 50.0,
    int resolution = 20, // nombre de points par degré
  }) {
    final dlon = (maxLon - minLon) / (resolution - 1);
    final dlat = (maxLat - minLat) / (resolution - 1);
    final nx = resolution;
    final ny = resolution;

    // Génère des valeurs de vent réalistes
    // Vent moyen: 5-15 m/s, varie avec la latitude et longitude
    final values = <double>[];
    
    for (int iy = 0; iy < ny; iy++) {
      final lat = minLat + iy * dlat;
      for (int ix = 0; ix < nx; ix++) {
        final lon = minLon + ix * dlon;
        
        // Vecteur de vent synthétique basé sur position
        // Simule des patterns réalistes
        final baseWind = 8.0; // vitesse moyenne
        
        // Ajouter de la variation avec latitude (Coriolis effect)
        final latVar = math.sin((lat - 40.0) / 5.0) * 3.0;
        
        // Ajouter de la variation avec longitude (ridge/trough)
        final lonVar = math.sin(lon * math.pi / 10.0) * 2.0;
        
        // Ajouter du bruit pour faire réaliste
        final noise = (math.Random(iy * nx + ix).nextDouble() - 0.5) * 2.0;
        
        final windSpeed = baseWind + latVar + lonVar + noise;
        values.add(windSpeed.clamp(1.0, 20.0));
      }
    }

    return ScalarGrid(
      nx: nx,
      ny: ny,
      lon0: minLon,
      lat0: minLat,
      dlon: dlon,
      dlat: dlat,
      values: Float32List.fromList(values),
    );
  }

  /// Génère une paire de grilles U/V (composantes Est/Nord du vent)
  static (ScalarGrid, ScalarGrid) generateTestWindVectors({
    double minLon = -10.0,
    double maxLon = 10.0,
    double minLat = 40.0,
    double maxLat = 50.0,
    int resolution = 20,
  }) {
    final dlon = (maxLon - minLon) / (resolution - 1);
    final dlat = (maxLat - minLat) / (resolution - 1);
    final nx = resolution;
    final ny = resolution;

    final uValues = <double>[];
    final vValues = <double>[];
    
    for (int iy = 0; iy < ny; iy++) {
      final lat = minLat + iy * dlat;
      for (int ix = 0; ix < nx; ix++) {
        final lon = minLon + ix * dlon;
        
        // Direction globale: vent du NW vers SE (environ 315° → 135°)
        // Composante U (Est): positive = vent venant de l'Ouest
        // Composante V (Nord): positive = vent venant du Sud
        
        final baseDir = 315.0; // NW
        final latModulation = (lat - 40.0) / 5.0 * 30.0; // ±30° variation
        final lonModulation = math.sin(lon * math.pi / 10.0) * 20.0; // ±20° variation
        
        final direction = (baseDir + latModulation + lonModulation) * math.pi / 180.0;
        
        final speed = (8.0 + math.sin(lon * math.pi / 10.0) * 3.0).clamp(2.0, 18.0);
        
        // Convertir direction/speed en U/V
        // Direction 0° = N, 90° = E, 180° = S, 270° = W
        // u = speed * sin(direction), v = speed * cos(direction)
        final u = speed * math.sin(direction);
        final v = speed * math.cos(direction);
        
        uValues.add(u);
        vValues.add(v);
      }
    }

    final uGrid = ScalarGrid(
      nx: nx,
      ny: ny,
      lon0: minLon,
      lat0: minLat,
      dlon: dlon,
      dlat: dlat,
      values: Float32List.fromList(uValues),
    );

    final vGrid = ScalarGrid(
      nx: nx,
      ny: ny,
      lon0: minLon,
      lat0: minLat,
      dlon: dlon,
      dlat: dlat,
      values: Float32List.fromList(vValues),
    );

    return (uGrid, vGrid);
  }
}
