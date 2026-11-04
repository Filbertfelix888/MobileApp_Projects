import 'package:flutter/material.dart';

class ThemeNotifier {
  // Static ValueNotifier agar bisa diakses dari mana saja
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  static bool get isDark => themeMode.value == ThemeMode.dark;

  static void toggleTheme() {
    themeMode.value = themeMode.value == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
  }
}