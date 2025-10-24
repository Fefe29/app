/// Application theming utilities.
/// See ARCHITECTURE_DOCS.md (section: lib/theme/app_theme.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appThemeProvider = Provider<AppTheme>((ref) => AppTheme());

class AppTheme {
  ThemeData get light => ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: const Color(0xFF006BA4), // Bleu tech
          onPrimary: Colors.white,
          secondary: const Color(0xFF00FFD0), // Vert néon
          onSecondary: Colors.black,
          background: const Color(0xFFF6F8FA),
          onBackground: Colors.black87,
          surface: Colors.white,
          onSurface: Colors.black87,
          error: Colors.redAccent,
          onError: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, letterSpacing: 0.5),
          titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
          labelLarge: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FFD0),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            elevation: 2,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF006BA4),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF23A8F2),
          contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        visualDensity: VisualDensity.comfortable,
      );

  ThemeData get dark => ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: const Color(0xFF23A8F2), // Bleu néon
          onPrimary: Colors.black,
          secondary: const Color(0xFFFF005C), // Rose néon
          onSecondary: Colors.white,
          background: const Color(0xFF181A20),
          onBackground: Colors.white,
          surface: const Color(0xFF23262F),
          onSurface: Colors.white,
          error: Colors.redAccent,
          onError: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: Color(0xFF00FFD0)),
          titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 22, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
          labelLarge: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF00FFD0)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF005C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            elevation: 2,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF23262F),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181A20),
          foregroundColor: Color(0xFF00FFD0),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF00FFD0)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: const Color(0xFF23262F),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFFFF005C),
          contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        visualDensity: VisualDensity.comfortable,
      );
}
