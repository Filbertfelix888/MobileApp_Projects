import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_palette.dart';

class ThemeNotifier {
  static const _modePreferenceKey = 'APP_THEME_MODE';
  static const _palettePreferenceKey = 'APP_THEME_PALETTE';
  static const _brandPreferenceKey = 'APP_BRAND';

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.system,
  );
  static final ValueNotifier<AppPalette> palette = ValueNotifier(
    AppPalette.ocean,
  );
  static final ValueNotifier<AppBrandMark> brand = ValueNotifier(
    AppBrandMark.logo,
  );

  /// Rebuilds the app when the mode, palette, or brand mark changes.
  static final Listenable appearance = Listenable.merge([
    themeMode,
    palette,
    brand,
  ]);

  static Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      themeMode.value = switch (preferences.getString(_modePreferenceKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.system,
      };
      palette.value = _paletteFrom(
        preferences.getString(_palettePreferenceKey),
      );
      brand.value = _brandFrom(preferences.getString(_brandPreferenceKey));
    } catch (_) {
      themeMode.value = ThemeMode.system;
      palette.value = AppPalette.ocean;
      brand.value = AppBrandMark.logo;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final saved = await (await SharedPreferences.getInstance()).setString(
      _modePreferenceKey,
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

  static Future<void> setPalette(AppPalette value) async {
    palette.value = value;
    final saved = await (await SharedPreferences.getInstance()).setString(
      _palettePreferenceKey,
      value.name,
    );
    if (!saved) {
      throw StateError('Palette preference could not be saved');
    }
  }

  static Future<void> setBrand(AppBrandMark value) async {
    brand.value = value;
    final saved = await (await SharedPreferences.getInstance()).setString(
      _brandPreferenceKey,
      value.name,
    );
    if (!saved) {
      throw StateError('Brand preference could not be saved');
    }
  }

  static AppPalette _paletteFrom(String? value) {
    for (final palette in AppPalette.values) {
      if (palette.name == value) return palette;
    }
    return AppPalette.ocean;
  }

  static AppBrandMark _brandFrom(String? value) {
    for (final brand in AppBrandMark.values) {
      if (brand.name == value) return brand;
    }
    return AppBrandMark.logo;
  }
}
