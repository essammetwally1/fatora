import 'package:flutter/material.dart';

import '../data/services/hive_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider() {
    _loadTheme();
  }

  bool _isDark = false;

  bool get isDark => _isDark;

  ThemeMode get themeMode {
    return _isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void _loadTheme() {
    final settingsBox = HiveService.getSettingsBox();

    final savedThemeMode = settingsBox.get(
      HiveService.themeModeKey,
      defaultValue: 'light',
    );

    _isDark = savedThemeMode == 'dark';
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;

    notifyListeners();

    await _saveTheme();
  }

  Future<void> setDarkMode() async {
    if (_isDark) return;

    _isDark = true;

    notifyListeners();

    await _saveTheme();
  }

  Future<void> setLightMode() async {
    if (!_isDark) return;

    _isDark = false;

    notifyListeners();

    await _saveTheme();
  }

  Future<void> _saveTheme() async {
    await HiveService.getSettingsBox().put(
      HiveService.themeModeKey,
      _isDark ? 'dark' : 'light',
    );
  }
}
