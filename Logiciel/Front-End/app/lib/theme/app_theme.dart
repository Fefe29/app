import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appThemeProvider = Provider<AppTheme>((ref) => AppTheme());

class AppTheme {
  ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006BA4)),
        useMaterial3: true,
        visualDensity: VisualDensity.comfortable,
      );

  ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF23A8F2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}
