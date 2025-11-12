/// NMEA 0183 Sentence Parser
/// 
/// Parseur pour phrases NMEA 0183 provenant du module Miniplexe 2Wi
/// Support des sentences principales pour navigateurs :
/// - RMC (Recommended Minimum Course/Time) : position, route, date
/// - VWT (True Wind) : vitesse et direction du vent vrai
/// - MWV (Wind Speed and Angle) : vitesse/angle du vent apparent ou vrai
/// - DPT (Depth) : profondeur
/// - MTW (Mean Temperature of Water) : température eau
/// 
/// Format NMEA 0183 standard: $AABBCCC,d1,d2,...,dN*HH\r\n
/// où: AA = talker, BBccc = sentence formatter, * = checksum

import 'package:kornog/domain/entities/telemetry.dart';

/// Résultat du parsing d'une sentence NMEA
class NmeaSentenceResult {
  const NmeaSentenceResult({
    required this.isValid,
    required this.sentenceType,
    required this.measurements,
    this.errorMessage,
  });

  final bool isValid;
  final String sentenceType; // e.g., "RMC", "VWT", "MWV"
  final Map<String, Measurement> measurements; // dotted keys e.g., "nav.lat", "wind.tws"
  final String? errorMessage;

  @override
  String toString() => 'NmeaSentenceResult($sentenceType, valid=$isValid, ${measurements.length} metrics)';
}

/// Parser NMEA 0183
class NmeaParser {
  /// Parse une phrase NMEA et retourne les mesures extraites
  /// 
  /// Retourne un [NmeaSentenceResult] avec les métriques parsées
  /// ou un résultat invalide si parsing échoue
  static NmeaSentenceResult parse(String sentence) {
    try {
      // Nettoyer la phrase
      final trimmed = sentence.trim();
      if (!trimmed.startsWith('\$')) {
        return NmeaSentenceResult(
          isValid: false,
          sentenceType: 'UNKNOWN',
          measurements: {},
          errorMessage: 'Sentence does not start with \$',
        );
      }

      // Extraire checksum si présent
      final checksumIdx = trimmed.indexOf('*');
      String sentenceData = trimmed;
      if (checksumIdx != -1) {
        final providedChecksum = trimmed.substring(checksumIdx + 1);
        sentenceData = trimmed.substring(0, checksumIdx);
        
        // Vérifier checksum (optionnel, mais recommandé)
        if (!_verifyChecksum(sentenceData, providedChecksum)) {
          // Log warning mais continue (certains devices envoient des checksums incorrects)
          // ignore: avoid_print
          print('⚠️ NMEA checksum invalid for: $trimmed');
        }
      }

      // Parser la phrase
      final parts = sentenceData.substring(1).split(',');
      if (parts.isEmpty) {
        return NmeaSentenceResult(
          isValid: false,
          sentenceType: 'UNKNOWN',
          measurements: {},
          errorMessage: 'Empty sentence parts',
        );
      }

      // Extraire le type de sentence (e.g., "GPRMC", "IIVWT")
      final header = parts[0];
      if (header.length < 3) {
        return NmeaSentenceResult(
          isValid: false,
          sentenceType: 'UNKNOWN',
          measurements: {},
          errorMessage: 'Invalid header: $header',
        );
      }

      // Extraire le talker (2 chars) et sentence formatter (3 chars)
      final talker = header.substring(0, 2); // e.g., "GP", "II"
      final sentenceType = header.substring(2).toUpperCase(); // e.g., "RMC", "VWT"

      final now = DateTime.now();
      final measurements = <String, Measurement>{};

      switch (sentenceType) {
        case 'RMC': // Recommended Minimum Course/Time
          _parseRMC(parts, now, measurements);
          break;
        case 'VWT': // True Wind
          _parseVWT(parts, now, measurements);
          break;
        case 'MWV': // Wind Speed and Angle
          _parseMWV(parts, now, measurements);
          break;
        case 'DPT': // Depth
          _parseDPT(parts, now, measurements);
          break;
        case 'MTW': // Mean Temperature of Water
          _parseMTW(parts, now, measurements);
          break;
        case 'HDT': // Heading True
          _parseHDT(parts, now, measurements);
          break;
        case 'VHW': // Water Speed and Heading
          _parseVHW(parts, now, measurements);
          break;
        case 'GLL': // Geographic Position
          _parseGLL(parts, now, measurements);
          break;
        default:
          // Sentence non supportée, mais pas erreur
          break;
      }

      return NmeaSentenceResult(
        isValid: true,
        sentenceType: sentenceType,
        measurements: measurements,
      );
    } catch (e, st) {
      return NmeaSentenceResult(
        isValid: false,
        sentenceType: 'UNKNOWN',
        measurements: {},
        errorMessage: 'Parse error: $e\n$st',
      );
    }
  }

  /// Parse RMC sentence (position, course, date, speed)
  /// $GPRMC,hhmmss.ss,A,llll.ll,a,yyyyy.yy,a,x.x,x.x,ddmmyy,x.x,a*hh
  /// Status: A=Active, V=Void
  static void _parseRMC(List<String> parts, DateTime now, Map<String, Measurement> measurements) {
    if (parts.length < 10) return;

    final status = parts[2].trim();
    if (status != 'A') return; // Ignore invalid status

    // Latitude (position 3, format: ddmm.mmmm, N/S at position 4)
    try {
      final latStr = parts[3].trim();
      final latNS = parts[4].trim();
      if (latStr.isNotEmpty && latNS.isNotEmpty) {
        final lat = _parseLatLon(latStr);
        if (lat != null) {
          final latValue = latNS == 'S' ? -lat : lat;
          measurements['nav.lat'] = Measurement(
            value: latValue,
            unit: Unit.degree,
            ts: now,
          );
        }
      }
    } catch (_) {}

    // Longitude (position 5, format: dddmm.mmmm, E/W at position 6)
    try {
      final lonStr = parts[5].trim();
      final lonEW = parts[6].trim();
      if (lonStr.isNotEmpty && lonEW.isNotEmpty) {
        final lon = _parseLatLon(lonStr);
        if (lon != null) {
          final lonValue = lonEW == 'W' ? -lon : lon;
          measurements['nav.lon'] = Measurement(
            value: lonValue,
            unit: Unit.degree,
            ts: now,
          );
        }
      }
    } catch (_) {}

    // Speed Over Ground (nœuds)
    try {
      final sog = double.parse(parts[7].trim());
      measurements['nav.sog'] = Measurement(
        value: sog,
        unit: Unit.knot,
        ts: now,
      );
    } catch (_) {}

    // Course Over Ground (degrés)
    try {
      final cog = double.parse(parts[8].trim());
      measurements['nav.cog'] = Measurement(
        value: cog % 360,
        unit: Unit.degree,
        ts: now,
      );
    } catch (_) {}
  }

  /// Parse VWT sentence (True Wind)
  /// $IIVWT,x.x,T,x.x,M,x.x,N,x.x,K*hh
  /// Format: Direction(T), Direction(M), Speed(N), Speed(K)
  /// T=True, M=Magnetic, N=Knots, K=Km/h
  static void _parseVWT(List<String> parts, DateTime now, Map<String, Measurement> measurements) {
    if (parts.length < 4) return;

    // True Wind Direction (après VWT, avant T)
    try {
      final twdStr = parts[1].trim();
      if (twdStr.isNotEmpty) {
        final twd = double.parse(twdStr);
        measurements['wind.twd'] = Measurement(
          value: twd % 360,
          unit: Unit.degree,
          ts: now,
        );
      }
    } catch (_) {}

    // True Wind Speed (Knots) - généralement en position 3 (après 'M')
    try {
      final twsStr = parts[3].trim();
      if (twsStr.isNotEmpty) {
        final tws = double.parse(twsStr);
        measurements['wind.tws'] = Measurement(
          value: tws,
          unit: Unit.knot,
          ts: now,
        );
      }
    } catch (_) {}
  }

  /// Parse MWV sentence (Wind Speed and Angle)
  /// $IIMWV,x.x,T/R,x.x,N/K/M/S,A/V*hh
  /// x.x = angle, T=True/R=Relative, speed, N/K/M/S = unit, A/V = valid
  static void _parseMWV(List<String> parts, DateTime now, Map<String, Measurement> measurements) {
    if (parts.length < 5) return;

    final angle = parts[1].trim();
    final reference = parts[2].trim();
    final speed = parts[3].trim();
    final speedUnit = parts[4].trim();
    final status = parts.length > 5 ? parts[5].trim() : 'A';

    if (status == 'V') return; // Invalid status

    try {
      final angleVal = double.parse(angle);
      final speedVal = double.parse(speed);

      if (reference == 'T') {
        // True Wind
        measurements['wind.twa'] = Measurement(
          value: (angleVal > 180 ? angleVal - 360 : angleVal).clamp(-180, 180),
          unit: Unit.degree,
          ts: now,
        );
      } else if (reference == 'R') {
        // Relative (Apparent) Wind
        measurements['wind.awa'] = Measurement(
          value: (angleVal > 180 ? angleVal - 360 : angleVal).clamp(-180, 180),
          unit: Unit.degree,
          ts: now,
        );
      }

      // Speed (convert to knots if needed)
      double speedInKnots = speedVal;
      if (speedUnit == 'K') speedInKnots = speedVal / 1.852; // km/h to knots
      else if (speedUnit == 'M') speedInKnots = speedVal * 1.944; // m/s to knots
      else if (speedUnit == 'S') speedInKnots = speedVal * 1.944; // m/s to knots

      if (reference == 'T') {
        measurements['wind.tws'] = Measurement(
          value: speedInKnots,
          unit: Unit.knot,
          ts: now,
        );
      } else if (reference == 'R') {
        measurements['wind.aws'] = Measurement(
          value: speedInKnots,
          unit: Unit.knot,
          ts: now,
        );
      }
    } catch (_) {}
  }

  /// Parse DPT sentence (Depth)
  /// $IIDPT,x.x,x.x*hh
  /// Depth, Offset
  static void _parseDPT(List<String> parts, DateTime now, Map<String, Measurement> measurements) {
    if (parts.length < 2) return;

    try {
      final depth = double.parse(parts[1].trim());
      measurements['env.depth'] = Measurement(
        value: depth,
        unit: Unit.meter,
        ts: now,
      );
    } catch (_) {}
  }

  /// Parse MTW sentence (Mean Temperature of Water)
  /// $IIMTW,x.x,C*hh
  static void _parseMTW(List<String> parts, DateTime now, Map<String, Measurement> measurements) {
    if (parts.length < 2) return;

    try {
      final temp = double.parse(parts[1].trim());
      measurements['env.waterTemp'] = Measurement(
        value: temp,
        unit: Unit.celsius,
        ts: now,
      );
    } catch (_) {}
  }

  /// Parse HDT sentence (Heading True)
  /// $IIHDТ,x.x,T*hh
  static void _parseHDT(List<String> parts, DateTime now, Map<String, Measurement> measurements) {
    if (parts.length < 2) return;

    try {
      final heading = double.parse(parts[1].trim());
      measurements['nav.hdg'] = Measurement(
        value: heading % 360,
        unit: Unit.degree,
        ts: now,
      );
    } catch (_) {}
  }

  /// Parse VHW sentence (Water Speed and Heading)
  /// $IIVHW,x.x,T,x.x,M,x.x,N,x.x,K*hh
  /// Heading True, Heading Magnetic, Speed Knots, Speed Km/h
  static void _parseVHW(List<String> parts, DateTime now, Map<String, Measurement> measurements) {
    if (parts.length < 4) return;

    try {
      final headingTrue = double.parse(parts[1].trim());
      measurements['nav.hdg'] = Measurement(
        value: headingTrue % 360,
        unit: Unit.degree,
        ts: now,
      );

      final speedKnots = double.parse(parts[5].trim());
      measurements['nav.sow'] = Measurement(
        value: speedKnots,
        unit: Unit.knot,
        ts: now,
      );
    } catch (_) {}
  }

  /// Parse GLL sentence (Geographic Position)
  /// $GPGLL,llll.lll,a,yyyyy.yyy,a,hhmmss.ss,A*hh
  static void _parseGLL(List<String> parts, DateTime now, Map<String, Measurement> measurements) {
    if (parts.length < 5) return;

    try {
      // Latitude
      final latStr = parts[1].trim();
      final latHemi = parts[2].trim();
      if (latStr.isNotEmpty && latHemi.isNotEmpty) {
        final lat = _parseLatLon(latStr);
        if (lat != null) {
          final latValue = latHemi == 'S' ? -lat : lat;
          measurements['nav.lat'] = Measurement(
            value: latValue,
            unit: Unit.degree,
            ts: now,
          );
        }
      }

      // Longitude
      final lonStr = parts[3].trim();
      final lonHemi = parts[4].trim();
      if (lonStr.isNotEmpty && lonHemi.isNotEmpty) {
        final lon = _parseLatLon(lonStr);
        if (lon != null) {
          final lonValue = lonHemi == 'W' ? -lon : lon;
          measurements['nav.lon'] = Measurement(
            value: lonValue,
            unit: Unit.degree,
            ts: now,
          );
        }
      }
    } catch (_) {}
  }

  /// Convertir format DMS (ddmm.mmmm) vers degrés décimaux
  static double? _parseLatLon(String value) {
    // Format NMEA: ddmm.mmmm (lat) or dddmm.mmmm (lon)
    // Returns decimal degrees
    if (value.isEmpty) return null;
    
    try {
      final dotIdx = value.indexOf('.');
      if (dotIdx == -1) return null;
      
      // Déterminer si c'est lat (2 degrés) ou lon (3 degrés)
      // On suppose que tout avant "mm." est les degrés
      // Pour lat: ddmm.xxxx -> 4 chars avant le point = 2 degrés
      // Pour lon: dddmm.xxxx -> 5 chars avant le point = 3 degrés
      int degreeDigits = dotIdx - 2;
      if (degreeDigits < 2) return null;
      
      final degreesStr = value.substring(0, degreeDigits);
      final minutesStr = value.substring(degreeDigits);
      
      final degrees = int.parse(degreesStr);
      final minutes = double.parse(minutesStr);
      
      return degrees + (minutes / 60.0);
    } catch (_) {
      return null;
    }
  }

  static double _parseDMS(String dms) {
    if (dms.length < 5) return 0.0;
    
    final degrees = int.parse(dms.substring(0, dms.length - 7));
    final minutes = double.parse(dms.substring(dms.length - 7));
    return degrees + (minutes / 60.0);
  }

  /// Vérifier le checksum NMEA
  static bool _verifyChecksum(String sentence, String providedChecksum) {
    try {
      int checksum = 0;
      for (final char in sentence.runes) {
        checksum ^= char;
      }
      final calculatedChecksum = checksum.toRadixString(16).padLeft(2, '0').toUpperCase();
      return calculatedChecksum == providedChecksum.toUpperCase();
    } catch (_) {
      return false;
    }
  }
}
