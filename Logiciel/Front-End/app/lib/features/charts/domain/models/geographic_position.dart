/// Geographic coordinate system support for the sailing application.
/// Supports conversion between geographic coordinates (lat/lon) and local meters.
import 'dart:math' as math;

/// A geographic position with latitude and longitude in decimal degrees.
class GeographicPosition {
  const GeographicPosition({
    required this.latitude,
    required this.longitude,
  });

  /// Latitude in decimal degrees (-90 to +90, positive = North)
  final double latitude;
  
  /// Longitude in decimal degrees (-180 to +180, positive = East)
  final double longitude;

  /// Creates a copy with optional parameter overrides
  GeographicPosition copyWith({
    double? latitude,
    double? longitude,
  }) => GeographicPosition(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeographicPosition &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'GeographicPosition(lat: $latitude°, lon: $longitude°)';

  /// Format for display (degrees, minutes, seconds or decimal)
  String toFormattedString({bool useDMS = false}) {
    if (useDMS) {
      return '${_formatDMS(latitude, true)}, ${_formatDMS(longitude, false)}';
    } else {
      return '${latitude.toStringAsFixed(6)}°, ${longitude.toStringAsFixed(6)}°';
    }
  }

  String _formatDMS(double degrees, bool isLatitude) {
    final isNegative = degrees < 0;
    final absDegrees = degrees.abs();
    final d = absDegrees.floor();
    final minutes = (absDegrees - d) * 60;
    final m = minutes.floor();
    final s = (minutes - m) * 60;
    
    String direction;
    if (isLatitude) {
      direction = isNegative ? 'S' : 'N';
    } else {
      direction = isNegative ? 'W' : 'E';
    }
    
    return '${d}°${m.toString().padLeft(2, '0')}\'${s.toStringAsFixed(2).padLeft(5, '0')}"$direction';
  }
}

/// A local position in meters relative to an origin point
class LocalPosition {
  const LocalPosition({
    required this.x,
    required this.y,
  });

  /// East-West position in meters (positive = East)
  final double x;
  
  /// North-South position in meters (positive = North) 
  final double y;

  LocalPosition copyWith({
    double? x,
    double? y,
  }) => LocalPosition(
        x: x ?? this.x,
        y: y ?? this.y,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalPosition &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => 'LocalPosition(x: ${x.toStringAsFixed(1)}m, y: ${y.toStringAsFixed(1)}m)';
}

/// Coordinate system conversion utilities
class CoordinateConverter {
  /// Origin point for local coordinate system
  final GeographicPosition origin;
  
  /// Cached cosine of origin latitude for performance
  final double _cosOriginLat;

  CoordinateConverter({required this.origin}) 
    : _cosOriginLat = math.cos(origin.latitude * math.pi / 180.0);

  /// Convert geographic position to local meters
  LocalPosition geographicToLocal(GeographicPosition geo) {
    final deltaLat = geo.latitude - origin.latitude;
    final deltaLon = geo.longitude - origin.longitude;
    
    // Approximate conversion using spherical geometry
    // For small distances (< 100km), this is accurate enough for sailing
    final y = deltaLat * _metersPerDegreeLatitude;
    final x = deltaLon * _metersPerDegreeLatitude * _cosOriginLat;
    
    return LocalPosition(x: x, y: y);
  }

  /// Convert local meters to geographic position
  GeographicPosition localToGeographic(LocalPosition local) {
    final deltaLat = local.y / _metersPerDegreeLatitude;
    final deltaLon = local.x / (_metersPerDegreeLatitude * _cosOriginLat);
    
    return GeographicPosition(
      latitude: origin.latitude + deltaLat,
      longitude: origin.longitude + deltaLon,
    );
  }

  /// Calculate distance between two geographic points in meters
  static double distanceMeters(GeographicPosition pos1, GeographicPosition pos2) {
    const earthRadius = 6371000.0; // meters
    
    final lat1Rad = pos1.latitude * math.pi / 180.0;
    final lat2Rad = pos2.latitude * math.pi / 180.0;
    final deltaLatRad = (pos2.latitude - pos1.latitude) * math.pi / 180.0;
    final deltaLonRad = (pos2.longitude - pos1.longitude) * math.pi / 180.0;

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calculate bearing from pos1 to pos2 in degrees (0 = North, 90 = East)
  static double bearingDegrees(GeographicPosition pos1, GeographicPosition pos2) {
    final lat1Rad = pos1.latitude * math.pi / 180.0;
    final lat2Rad = pos2.latitude * math.pi / 180.0;
    final deltaLonRad = (pos2.longitude - pos1.longitude) * math.pi / 180.0;

    final y = math.sin(deltaLonRad) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLonRad);

    final bearingRad = math.atan2(y, x);
    return (bearingRad * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// Approximate meters per degree of latitude (constant)
  static const double _metersPerDegreeLatitude = 111320.0;
}

/// Default coordinate system configurations for different sailing areas
class CoordinateSystemPresets {
  /// Rade de Brest (Brittany, France)
  static final brest = GeographicPosition(latitude: 48.38, longitude: -4.50);
  
  /// Mediterranean (around French Riviera)
  static final mediterranean = GeographicPosition(latitude: 43.5, longitude: 7.0);
  
  /// English Channel (around Portsmouth)
  static final englishChannel = GeographicPosition(latitude: 50.8, longitude: -1.1);
  
  /// San Francisco Bay
  static final sanFranciscoBay = GeographicPosition(latitude: 37.8, longitude: -122.4);
  
  /// Sydney Harbour
  static final sydneyHarbour = GeographicPosition(latitude: -33.85, longitude: 151.2);
}