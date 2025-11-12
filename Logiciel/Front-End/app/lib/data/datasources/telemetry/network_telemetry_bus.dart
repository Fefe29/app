/// NetworkTelemetryBus : connexion UDP au module Miniplexe 2Wi
/// 
/// Implémentation de [TelemetryBus] qui:
/// - Écoute sur UDP les phrases NMEA 0183 du Miniplexe 2Wi
/// - Parse les sentences avec [NmeaParser]
/// - Émet les mesures extraites via les streams Riverpod
/// - Gère les reconnexions et erreurs réseau

import 'dart:async';
import 'dart:io';
import 'package:udp/udp.dart';
import 'package:kornog/data/datasources/telemetry/telemetry_bus.dart';
import 'package:kornog/domain/entities/telemetry.dart';
import 'package:kornog/common/services/nmea_parser.dart';

/// Configuration de connexion réseau
class NetworkConfig {
  const NetworkConfig({
    required this.host,
    required this.port,
    this.receiveBufferSize = 1024,
    this.connectionTimeoutSeconds = 10,
    this.reconnectIntervalSeconds = 5,
  });

  final String host; // Adresse IP du Miniplexe (ex: "192.168.1.100")
  final int port; // Port UDP (ex: 10110)
  final int receiveBufferSize;
  final int connectionTimeoutSeconds;
  final int reconnectIntervalSeconds;

  @override
  String toString() => 'NetworkConfig($host:$port)';
}

/// Classe pour représenter une trame NMEA parsée
class NmeaFrame {
  final String raw;
  final DateTime timestamp;
  final bool isValid;
  final String? errorMessage;

  NmeaFrame({
    required this.raw,
    required this.timestamp,
    this.isValid = true,
    this.errorMessage,
  });
}

/// Telemetry Bus connecté au réseau (UDP NMEA 0183)
class NetworkTelemetryBus implements TelemetryBus {
  NetworkTelemetryBus({
    required this.config,
  });

  final NetworkConfig config;

  UDP? _udp;
  final _snap$ = StreamController<TelemetrySnapshot>.broadcast();
  final _nmeaFrames$ = StreamController<NmeaFrame>.broadcast();
  final Map<String, StreamController<Measurement>> _keyStreams = {};
  Timer? _reconnectTimer;
  bool _isConnected = false;
  DateTime? _lastValidData;

  /// Getters publics pour suivre l'état
  bool get isConnected => _isConnected;
  DateTime? get lastValidData => _lastValidData;

  /// Connecter et démarrer la réception UDP
  Future<bool> connect() async {
    try {
      // ignore: avoid_print
      print('🌐 Tentative de connexion UDP: ${config.host}:${config.port}');

      _udp = await UDP.bind(
        Endpoint.unicast(
          InternetAddress('0.0.0.0'),
          port: Port(config.port),
        ),
      );

      _isConnected = true;
      _lastValidData = DateTime.now();

      // ignore: avoid_print
      print('✅ Connecté à UDP sur port ${config.port}');

      // Démarrer la lecture des données
      _startListening();

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Erreur connexion UDP: $e');
      _isConnected = false;
      _scheduleReconnect();
      return false;
    }
  }

  /// Lire en continu les données UDP
  void _startListening() {
    final subscription = _udp?.asStream().listen(
      (datagram) {
        try {
          if (datagram == null) return;

          final data = datagram.data;
          final sender = datagram.address;

          // Vérifier que c'est bien du Miniplexe (optionnel: filtrer par IP)
          // ex: if (sender.address != config.host) return;

          // Décoder la phrase NMEA
          final sentence = String.fromCharCodes(data).trim();
          if (sentence.isEmpty) return;

          // ignore: avoid_print
          print('📡 NMEA: $sentence');

          // Parser la sentence
          final result = NmeaParser.parse(sentence);
          if (!result.isValid) {
            // ignore: avoid_print
            print('⚠️ Parse invalide: ${result.errorMessage}');
            // Émettre sur le stream NMEA
            _nmeaFrames$.add(NmeaFrame(
              raw: sentence,
              timestamp: DateTime.now(),
              isValid: false,
              errorMessage: result.errorMessage,
            ));
            return;
          }

          // Émettre sur le stream NMEA (succès)
          _nmeaFrames$.add(NmeaFrame(
            raw: sentence,
            timestamp: DateTime.now(),
            isValid: true,
          ));

          _lastValidData = DateTime.now();

          // Emettre les mesures
          if (result.measurements.isNotEmpty) {
            final snap = TelemetrySnapshot(
              ts: DateTime.now(),
              metrics: result.measurements,
              tags: {
                'source': 'nmea_udp',
                'sentence_type': result.sentenceType,
                'sender': sender.address,
              },
            );
            _snap$.add(snap);

            // Emettre aussi par clé individuelle
            for (final entry in result.measurements.entries) {
              _keyStreams
                  .putIfAbsent(entry.key, () => StreamController<Measurement>.broadcast())
                  .add(entry.value);
            }
          }
        } catch (e, st) {
          // ignore: avoid_print
          print('❌ Erreur traitement datagram: $e\n$st');
        }
      },
      onError: (error, stackTrace) {
        // ignore: avoid_print
        print('❌ Erreur UDP stream: $error');
        _isConnected = false;
        _scheduleReconnect();
      },
      onDone: () {
        // ignore: avoid_print
        print('⚠️ UDP stream fermé');
        _isConnected = false;
        _scheduleReconnect();
      },
    );
  }

  /// Planifier une reconnexion après délai
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(seconds: config.reconnectIntervalSeconds),
      () {
        // ignore: avoid_print
        print('🔄 Tentative de reconnexion...');
        connect();
      },
    );
  }

  @override
  Stream<TelemetrySnapshot> snapshots() => _snap$.stream;

  /// Stream des trames NMEA reçues (avant parsing)
  Stream<NmeaFrame> nmeaFrames() => _nmeaFrames$.stream;

  @override
  Stream<Measurement> watch(String key) =>
      _keyStreams.putIfAbsent(key, () => StreamController<Measurement>.broadcast()).stream;

  /// Nettoyer et fermer la connexion
  void dispose() {
    _reconnectTimer?.cancel();
    _udp?.close();
    _snap$.close();
    _nmeaFrames$.close();
    for (final c in _keyStreams.values) {
      c.close();
    }
  }
}
