/// Theme provider for managing dark mode override
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier for managing theme mode
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void toggleDarkMode() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.system;
    } else {
      state = ThemeMode.dark;
    }
  }
}

/// Provider for theme mode
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});
