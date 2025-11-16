/// Theme provider for managing dark mode override
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier for managing theme mode
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

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
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
