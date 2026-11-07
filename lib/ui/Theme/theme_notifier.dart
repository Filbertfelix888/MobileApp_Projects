import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier {
  static const _preferenceKey = 'APP_THEME_MODE';
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.system,
  );

  static Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      themeMode.value = switch (preferences.getString(_preferenceKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.system,
      };
    } catch (_) {
      themeMode.value = ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final saved = await (await SharedPreferences.getInstance()).setString(
      _preferenceKey,
      switch (mode) {
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
      },
    );
    if (!saved) {
      throw StateError('Theme preference could not be saved');
    }
  }
}
