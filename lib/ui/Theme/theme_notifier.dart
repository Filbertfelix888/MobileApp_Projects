import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier {
  static const _preferenceKey = 'APP_THEME_MODE';
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.light,
  );

  static bool get isDark => themeMode.value == ThemeMode.dark;

  static Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      themeMode.value = preferences.getString(_preferenceKey) == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
    } catch (_) {
      themeMode.value = ThemeMode.light;
    }
  }

  static Future<void> toggleTheme() async {
    final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
    themeMode.value = nextMode;
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _preferenceKey,
      nextMode == ThemeMode.dark ? 'dark' : 'light',
    );
    if (!saved) {
      throw StateError('Theme preference could not be saved');
    }
  }
}
