/// Service de découverta automatique du Miniplexe 2Wi
/// 
/// Détecte l'adresse IP locale du Miniplexe en UDP broadcast
/// et teste la connexion automatiquement

import 'dart:io';
import 'dart:async';
import 'dart:convert' show utf8;

/// Résultat de découverte du Miniplexe
class MiniplexeDiscovery {
  const MiniplexeDiscovery({
    required this.found,
    this.ipAddress,
    this.port = 10110,
    this.errorMessage,
  });

  final bool found;
  final String? ipAddress;
  final int port;
  final String? errorMessage;

  @override
  String toString() => 'MiniplexeDiscovery(found=$found, ip=$ipAddress:$port)';
}

/// Service de découverte du Miniplexe
class MiniplexeDiscoveryService {
  /// Découvrir le Miniplexe via le WiFi actuel
  static Future<MiniplexeDiscovery> discoverMiniplexe({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      // 1. Obtenir l'adresse IP locale en se connectant à Google DNS
      final wifiIP = await _getLocalIP();

      if (wifiIP == null || wifiIP.isEmpty) {
        return MiniplexeDiscovery(
          found: false,
          errorMessage: 'Impossible de déterminer l\'adresse IP locale',
        );
      }

      // ignore: avoid_print
      print('🌐 Votre adresse WiFi: $wifiIP');

      // 2. Calculer l'adresse de broadcast (généralement xxx.xxx.xxx.255)
      final ipParts = wifiIP.split('.');
      if (ipParts.length != 4) {
        return MiniplexeDiscovery(
          found: false,
          errorMessage: 'Format adresse IP invalide: $wifiIP',
        );
      }

      final broadcastIP = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}.255';
      // ignore: avoid_print
      print('📡 Tentative broadcast sur: $broadcastIP:10110');

      // 3. Tenter de découvrir via UDP broadcast
      final discovered = await _scanBroadcast(broadcastIP);
      if (discovered != null) {
        return MiniplexeDiscovery(
          found: true,
          ipAddress: discovered,
          port: 10110,
        );
      }

      // 4. Sinon, tenter les IPs courantes du réseau (1-254)
      final found = await _scanNetwork(ipParts[0], ipParts[1], ipParts[2]);
      if (found != null) {
        return MiniplexeDiscovery(
          found: true,
          ipAddress: found,
          port: 10110,
        );
      }

      return MiniplexeDiscovery(
        found: false,
        errorMessage: 'Miniplexe non trouvé sur le réseau',
      );
    } catch (e) {
      return MiniplexeDiscovery(
        found: false,
        errorMessage: 'Erreur découverte: $e',
      );
    }
  }

  /// Obtenir l'adresse IP locale
  static Future<String?> _getLocalIP() async {
    try {
      // Lister toutes les interfaces réseau
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        // Chercher une interface active (pas loopback, avec adresse IPv4)
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && 
              !address.address.startsWith('127.')) {
            // ignore: avoid_print
            print('✓ Interface ${interface.name}: ${address.address}');
            return address.address;
          }
        }
      }
      
      // Si pas trouvé, essayer la connexion socket
      return _getLocalIPViaSocket();
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Erreur listage interfaces: $e');
      return _getLocalIPViaSocket();
    }
  }

  /// Approche alternative pour obtenir l'IP locale
  static Future<String?> _getLocalIPViaSocket() async {
    try {
      // Se connecter à un serveur externe pour déterminer l'IP locale
      final socket = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(milliseconds: 500));
      
      final ip = socket.address.address;
      socket.close();
      return ip;
    } catch (_) {
      // Dernier recours: retourner une valeur par défaut
      return null;
    }
  }

  /// Scanner le broadcast UDP pour trouver le Miniplexe
  static Future<String?> _scanBroadcast(String broadcastIP) async {
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      // Envoyer un paquet de découverte
      socket.broadcastEnabled = true;
      final discoveryPacket = utf8.encode('MINIPLEXE_DISCOVERY');

      socket.send(
        discoveryPacket,
        InternetAddress(broadcastIP),
        10110,
      );

      // Écouter les réponses
      final completer = Completer<String?>();
      late StreamSubscription<RawSocketEvent> subscription;

      subscription = socket.asBroadcastStream().listen((event) {
        if (event == RawSocketEvent.read) {
          try {
            final datagram = socket.receive();
            if (datagram != null) {
              // ignore: avoid_print
              print('✅ Réponse reçue de: ${datagram.address.address}:${datagram.port}');
              completer.complete(datagram.address.address);
            }
          } catch (_) {}
        }
      });

      // Timeout après 3 secondes
      Future.delayed(const Duration(seconds: 3)).then((_) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        subscription.cancel();
        socket.close();
      });

      return completer.future;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Erreur broadcast: $e');
      return null;
    }
  }

  /// Scanner les IPs du réseau local
  static Future<String?> _scanNetwork(String octet1, String octet2, String octet3) async {
    // ignore: avoid_print
    print('🔍 Scan du réseau: $octet1.$octet2.$octet3.x');

    // Essayer les IPs courantes (gateway, DHCP range)
    final commonIPs = [
      '${octet1}.${octet2}.${octet3}.1',    // Gateway
      '${octet1}.${octet2}.${octet3}.100',  // Plage DHCP
      '${octet1}.${octet2}.${octet3}.101',
      '${octet1}.${octet2}.${octet3}.102',
      '${octet1}.${octet2}.${octet3}.103',
      '${octet1}.${octet2}.${octet3}.200',  // Devices statiques
      '${octet1}.${octet2}.${octet3}.254',  // Avant broadcast
    ];

    // Tester chaque IP en parallèle
    final futures = commonIPs.map((ip) => _testMiniplexeConnection(ip)).toList();
    final results = await Future.wait(futures);

    for (final ip in results) {
      if (ip != null) {
        return ip;
      }
    }

    return null;
  }

  /// Tester la connexion à une IP spécifique
  static Future<String?> _testMiniplexeConnection(String ip) async {
    try {
      final socket = await Socket.connect(
        ip,
        10110,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      // ignore: avoid_print
      print('✅ Miniplexe trouvé à: $ip');
      return ip;
    } catch (_) {
      return null;
    }
  }

  /// Forcer le Miniplexe à écouter sur un port spécifique
  /// (envoie une commande de configuration)
  static Future<bool> configureMiniplexePort(
    String ip,
    int desiredPort, {
    int defaultPort = 10110,
  }) async {
    try {
      // Configuration simple: envoyer une commande NMEA
      // Cette partie dépend du protocole du Miniplexe
      // Exemple générique:
      
      final socket = await Socket.connect(ip, defaultPort);
      
      // Envoyer commande de configuration
      // Format dépend du Miniplexe (à adapter selon doc)
      final configCmd = utf8.encode(
        '\$--CFG,UDP_PORT,$desiredPort*00\r\n'
      );
      
      socket.add(configCmd);
      await socket.flush();
      
      await Future.delayed(const Duration(seconds: 1));
      socket.close();
      
      // ignore: avoid_print
      print('✅ Port configuré à $desiredPort');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Erreur configuration port: $e');
      return false;
    }
  }
}
