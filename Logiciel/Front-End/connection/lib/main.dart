import 'dart:io';

void main() async {
  final String ip = '10.0.0.10';  // L'adresse IP spécifique à tester
  final int port = 10110;         // Le port pour la connexion au Miniplex

  try {
    // Tester la connexion en utilisant un socket sur l'IP et le port
    final socket = await Socket.connect(ip, port, timeout: Duration(seconds: 5));
    print('Connexion établie à $ip:$port');
    socket.destroy();  // Fermer la connexion après le test
  } catch (e) {
    // Si la connexion échoue, afficher l'erreur
    print('Impossible de se connecter à $ip:$port');
  }
}

