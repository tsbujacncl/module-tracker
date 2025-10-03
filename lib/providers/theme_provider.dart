import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Theme mode options
enum AppThemeMode {
  light,
  dark,
  system;

  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System Default';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

/// Theme settings notifier
class ThemeNotifier extends StateNotifier<AppThemeMode> {
  static const String _themeKey = 'app_theme_mode';
  Box? _settingsBox;

  ThemeNotifier() : super(AppThemeMode.system) {
    _loadTheme();
  }

  /// Load saved theme preference
  Future<void> _loadTheme() async {
    try {
      _settingsBox = await Hive.openBox('settings');
      final savedTheme = _settingsBox?.get(_themeKey);

      if (savedTheme != null) {
        state = AppThemeMode.values.firstWhere(
          (mode) => mode.name == savedTheme,
          orElse: () => AppThemeMode.system,
        );
        print('DEBUG THEME: Loaded saved theme: ${state.displayName}');
      } else {
        print('DEBUG THEME: No saved theme, using system default');
      }
    } catch (e) {
      print('DEBUG THEME: Error loading theme - $e');
    }
  }

  /// Change theme mode
  Future<void> setThemeMode(AppThemeMode mode) async {
    print('DEBUG THEME: Changing theme to: ${mode.displayName}');
    state = mode;

    try {
      await _settingsBox?.put(_themeKey, mode.name);
      print('DEBUG THEME: Theme saved successfully');
    } catch (e) {
      print('DEBUG THEME: Error saving theme - $e');
    }
  }

  /// Get current ThemeMode for MaterialApp
  ThemeMode get currentThemeMode => state.themeMode;
}

/// Theme provider
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});
