/// Formatage des coordonnées en format nautique

/// Convertir des degrés décimaux en format DMS (Degrés Minutes Secondes)
/// Ex: 48.39393 -> 48°23'37.7"
String _formatDMS(double degrees, bool isLatitude) {
  final isNegative = degrees < 0;
  final absDegrees = degrees.abs();
  
  final deg = absDegrees.toInt();
  final minutesDecimal = (absDegrees - deg) * 60;
  final min = minutesDecimal.toInt();
  final sec = (minutesDecimal - min) * 60;
  
  final hemi = isLatitude 
    ? (isNegative ? 'S' : 'N')
    : (isNegative ? 'W' : 'E');
    
  return '${deg.toString().padLeft(isLatitude ? 2 : 3, '0')}°${min.toString().padLeft(2, '0')}\'${sec.toStringAsFixed(1).padLeft(4, '0')}"$hemi';
}

/// Formater une position (latitude, longitude) en format nautique
/// Ex: "48°23'37.6\"N 004°15'56.2\"W"
String formatPosition(double latitude, double longitude) {
  final latStr = _formatDMS(latitude, true);
  final lonStr = _formatDMS(longitude, false);
  return '$latStr $lonStr';
}

/// Format court pour affichage compact
/// Ex: "48°23.63'N 4°15.94'W"
String formatPositionShort(double latitude, double longitude) {
  final isLatNeg = latitude < 0;
  final isLonNeg = longitude < 0;
  
  final absLat = latitude.abs();
  final absLon = longitude.abs();
  
  final latDeg = absLat.toInt();
  final latMin = (absLat - latDeg) * 60;
  
  final lonDeg = absLon.toInt();
  final lonMin = (absLon - lonDeg) * 60;
  
  final latHemi = isLatNeg ? 'S' : 'N';
  final lonHemi = isLonNeg ? 'W' : 'E';
  
  return '${latDeg.toString().padLeft(2, '0')}°${latMin.toStringAsFixed(2).padLeft(5, '0')}\' $latHemi ${lonDeg.toString().padLeft(3, '0')}°${lonMin.toStringAsFixed(2).padLeft(5, '0')}\' $lonHemi';
}
