/// Theme service — Telegram-like appearance customization (Decision_Log —
/// Themes; FR-010). Accent color, icons (future), map style.
import 'package:flutter/material.dart';

import 'package:pokatuha/database/collections/settings_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';

class ThemeService {
  ThemeService();

  AppThemeMode _mode = AppThemeMode.dark;
  Color _accent = const Color(0xFF3B82F6);

  AppThemeMode get mode => _mode;
  Color get accent => _accent;

  ThemeMode get flutterThemeMode => switch (_mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.amoled => ThemeMode.dark,
      };

  void applyFromSettings(SettingsCollection settings) {
    _mode = AppThemeMode.values.firstWhere(
      (e) => e.name == settings.themeMode,
      orElse: () => AppThemeMode.dark,
    );
    _accent = Color(settings.accentColor);
  }

  void setMode(AppThemeMode mode) => _mode = mode;
  void setAccent(Color accent) => _accent = accent;

  /// Default accent presets (FR-010).
  static const List<Color> accentPresets = [
    Color(0xFF3B82F6), // blue
    Color(0xFF22C55E), // green
    Color(0xFFF97316), // orange
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFFEAB308), // amber
  ];
}
