#!/usr/bin/env dart
/// Script pour configurer le build selon la plateforme cible
/// Usage: dart setup_build.dart linux
/// ou:    dart setup_build.dart android

import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Erreur: plateforme requise');
    print('Usage: dart setup_build.dart [linux|android]');
    exit(1);
  }

  final platform = args[0].toLowerCase();
  final pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) {
    print('❌ Erreur: pubspec.yaml non trouvé');
    exit(1);
  }

  print('🔧 Configuration du build pour: $platform');

  String content = pubspecFile.readAsStringSync();

  if (platform == 'linux') {
    print('📝 Commentant audioplayers pour build Linux...');
    // Commenter audioplayers
    content = content.replaceAll(
      RegExp(r'^  audioplayers: \^6\.0\.0.*$', multiLine: true),
      '  # audioplayers: ^6.0.0  # Disabled for Linux (GStreamer)',
    );
  } else if (platform == 'android') {
    print('📝 Activant audioplayers pour build Android...');
    // Décommenter audioplayers
    content = content.replaceAll(
      RegExp(r'^  # audioplayers: \^6\.0\.0.*$', multiLine: true),
      '  audioplayers: ^6.0.0',
    );
  } else {
    print('❌ Erreur: plateforme inconnue: $platform');
    print('Platforms supportées: linux, android');
    exit(1);
  }

  pubspecFile.writeAsStringSync(content);
  print('✅ Build configuré pour $platform');
  print('');
  print('Exécute maintenant:');
  if (platform == 'linux') {
    print('  flutter pub get');
    print('  flutter run -d linux');
  } else if (platform == 'android') {
    print('  flutter pub get');
    print('  flutter run -d android');
  }
}
