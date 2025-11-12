/// Tests pour le parser NMEA 0183
/// 
/// À placer dans: test/nmea_parser_test.dart
/// Exécuter avec: flutter test test/nmea_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:kornog/common/services/nmea_parser.dart';
import 'package:kornog/domain/entities/telemetry.dart';

void main() {
  group('NmeaParser Tests', () {
    test('Parse VWT sentence - True Wind', () {
      const sentence = '\$IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*42';
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, true);
      expect(result.sentenceType, 'VWT');
      expect(result.measurements.containsKey('wind.twd'), true);
      expect(result.measurements['wind.twd']?.value, 270.0);
      expect(result.measurements['wind.tws']?.value, 12.5);
    });

    test('Parse RMC sentence - Position & Course', () {
      const sentence = '\$GPRMC,081350.00,A,4717.113210,N,00833.915187,E,1.295,90.0,050905,,,A*78';
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, true);
      expect(result.sentenceType, 'RMC');
      expect(result.measurements.containsKey('nav.sog'), true);
      expect(result.measurements.containsKey('nav.cog'), true);
      expect(result.measurements['nav.sog']?.value, closeTo(1.295, 0.001));
      expect(result.measurements['nav.cog']?.value, 90.0);
    });

    test('Parse MWV sentence - Wind Speed & Angle (True)', () {
      const sentence = '\$IIMWV,45.0,T,15.5,N,A*3D';
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, true);
      expect(result.sentenceType, 'MWV');
      expect(result.measurements.containsKey('wind.twa'), true);
      expect(result.measurements['wind.twa']?.value, closeTo(45.0, 0.1));
      expect(result.measurements['wind.tws']?.value, closeTo(15.5, 0.1));
    });

    test('Parse MWV sentence - Wind Speed & Angle (Apparent)', () {
      const sentence = '\$IIMWV,120.0,R,18.2,N,A*31';
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, true);
      expect(result.sentenceType, 'MWV');
      expect(result.measurements.containsKey('wind.awa'), true);
      expect(result.measurements['wind.awa']?.value, closeTo(120.0, 0.1));
      expect(result.measurements['wind.aws']?.value, closeTo(18.2, 0.1));
    });

    test('Parse DPT sentence - Depth', () {
      const sentence = '\$IIDPT,15.3,0.5*3A';
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, true);
      expect(result.sentenceType, 'DPT');
      expect(result.measurements.containsKey('env.depth'), true);
      expect(result.measurements['env.depth']?.value, closeTo(15.3, 0.1));
    });

    test('Parse MTW sentence - Water Temperature', () {
      const sentence = '\$IIMTW,18.5,C*25';
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, true);
      expect(result.sentenceType, 'MTW');
      expect(result.measurements.containsKey('env.waterTemp'), true);
      expect(result.measurements['env.waterTemp']?.value, closeTo(18.5, 0.1));
    });

    test('Parse HDT sentence - Heading True', () {
      const sentence = '\$IIHDТ,180.5,T*34';
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, true);
      expect(result.sentenceType, 'HDT');
      expect(result.measurements.containsKey('nav.hdg'), true);
    });

    test('Parse VHW sentence - Water Speed & Heading', () {
      const sentence = '\$IIVHW,90.0,T,85.5,M,6.8,N,12.6,K*5C';
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, true);
      expect(result.sentenceType, 'VHW');
      expect(result.measurements.containsKey('nav.hdg'), true);
      expect(result.measurements.containsKey('nav.sow'), true);
    });

    test('Invalid sentence without dollar sign', () {
      const sentence = 'IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*42';
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('does not start with'));
    });

    test('Invalid sentence with bad checksum', () {
      const sentence = '\$IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*00';
      final result = NmeaParser.parse(sentence);

      // Parser continue même avec mauvais checksum (warning seulement)
      expect(result.isValid, true);
    });

    test('Empty sentence parts', () {
      const sentence = '\$';
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, false);
    });

    test('Unsupported sentence type', () {
      const sentence = '\$IIGLL,4717.113210,N,00833.915187,E,081350.00,A*5C';
      final result = NmeaParser.parse(sentence);

      // Sentence supportée mais vérifier les mesures extraites
      expect(result.isValid, true);
      expect(result.sentenceType, 'GLL');
    });

    test('Convert units - km/h to knots in MWV', () {
      // 42.636 km/h ≈ 23.0 knots
      const sentence = '\$IIMWV,45.0,T,23.0,K,A*3C'; // K = km/h
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, true);
      final speedKnots = result.measurements['wind.tws']?.value;
      expect(speedKnots, isNotNull);
      // 23.0 km/h ÷ 1.852 ≈ 12.42 knots
      expect(speedKnots, closeTo(12.4, 0.2));
    });

    test('Parse negative wind angles', () {
      const sentence = '\$IIMWV,315.0,R,15.0,N,A*3E'; // 315° ≈ -45°
      final result = NmeaParser.parse(sentence);

      expect(result.isValid, true);
      final angle = result.measurements['wind.awa']?.value;
      expect(angle, isNotNull);
      // 315° should be converted to -45° or wrapped to 315°
      expect((angle! > 180 ? angle - 360 : angle), lessThan(0));
    });

    test('Checksum verification - valid', () {
      // Checksum calculé: XOR de tous les caractères entre $ et *
      const sentence = '\$IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*42';
      final result = NmeaParser.parse(sentence);
      
      // Devrait être valide (ne pas échouer)
      expect(result.isValid, true);
    });

    test('Multiple consecutive sentences', () {
      // Tester le parsing de sentences multiples
      final sentences = [
        '\$IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*42',
        '\$GPRMC,081350.00,A,4717.113210,N,00833.915187,E,1.295,90.0,050905,,,A*78',
        '\$IIMWV,45.0,T,15.5,N,A*3D',
      ];

      final results = sentences.map(NmeaParser.parse).toList();

      expect(results[0].sentenceType, 'VWT');
      expect(results[1].sentenceType, 'RMC');
      expect(results[2].sentenceType, 'MWV');

      // Tous valides
      expect(results.every((r) => r.isValid), true);
    });
  });

  group('Unit Tests', () {
    test('Measurement with Unit.knot', () {
      final measurement = Measurement(
        value: 12.5,
        unit: Unit.knot,
        ts: DateTime.now(),
      );

      expect(measurement.value, 12.5);
      expect(measurement.unit.symbol, 'kn');
    });

    test('Measurement with Unit.degree', () {
      final measurement = Measurement(
        value: 270.0,
        unit: Unit.degree,
        ts: DateTime.now(),
      );

      expect(measurement.value, 270.0);
      expect(measurement.unit.symbol, '°');
    });
  });
}
