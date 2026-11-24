import 'package:flutter/material.dart';

/// Curated palette identities. Only the accent roles change; neutral surfaces
/// stay shared so contrast and layout remain predictable.
enum AppPalette {
  ocean('Biru', Color(0xFF345BC7)),
  forest('Hijau', Color(0xFF1F6B45)),
  violet('Ungu', Color(0xFF6B3FA0)),
  sunset('Senja', Color(0xFFA8431A)),
  softPink('Pink Lembut', Color(0xFFA63D63)),
  graphite('Grafit', Color(0xFF3F4756));

  const AppPalette(this.label, this.swatch);

  final String label;

  /// Representative colour used by the palette chooser.
  final Color swatch;

  AppPaletteColors get light => _lightPaletteColors[this]!;
  AppPaletteColors get dark => _darkPaletteColors[this]!;
}

/// The accent roles a palette overrides on top of the shared neutral scheme.
class AppPaletteColors {
  const AppPaletteColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.inversePrimary,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color inversePrimary;
}

/// In-app brand marks. The launcher icon is a native resource and is not
/// runtime-customisable; this only changes the mark shown inside the app.
enum AppBrandMark {
  logo('Default', Icons.business),
  rocket('Roket', Icons.rocket_launch),
  folder('Folder', Icons.folder_open),
  layers('Lapisan', Icons.layers),
  target('Target', Icons.track_changes);

  const AppBrandMark(this.label, this.icon);

  final String label;
  final IconData icon;

  bool get usesLogoAsset => this == AppBrandMark.logo;
}

const Map<AppPalette, AppPaletteColors> _lightPaletteColors = {
  AppPalette.ocean: AppPaletteColors(
    primary: Color(0xFF345BC7),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3EAFF),
    onPrimaryContainer: Color(0xFF203A78),
    inversePrimary: Color(0xFFADC6FF),
  ),
  AppPalette.forest: AppPaletteColors(
    primary: Color(0xFF1F6B45),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDDF3E6),
    onPrimaryContainer: Color(0xFF0B3A25),
    inversePrimary: Color(0xFF8FD5AE),
  ),
  AppPalette.violet: AppPaletteColors(
    primary: Color(0xFF6B3FA0),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF0E4FF),
    onPrimaryContainer: Color(0xFF3A1D5C),
    inversePrimary: Color(0xFFD6B8FF),
  ),
  AppPalette.sunset: AppPaletteColors(
    primary: Color(0xFFA8431A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE3D3),
    onPrimaryContainer: Color(0xFF5A2410),
    inversePrimary: Color(0xFFFFB59A),
  ),
  AppPalette.softPink: AppPaletteColors(
    primary: Color(0xFFA63D63),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE1EC),
    onPrimaryContainer: Color(0xFF5C1734),
    inversePrimary: Color(0xFFFFB1CC),
  ),
  AppPalette.graphite: AppPaletteColors(
    primary: Color(0xFF3F4756),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE7EAF0),
    onPrimaryContainer: Color(0xFF252B36),
    inversePrimary: Color(0xFFC7CFDD),
  ),
};

const Map<AppPalette, AppPaletteColors> _darkPaletteColors = {
  AppPalette.ocean: AppPaletteColors(
    primary: Color(0xFFADC6FF),
    onPrimary: Color(0xFF172B55),
    primaryContainer: Color(0xFF2B3D62),
    onPrimaryContainer: Color(0xFFE3EAFF),
    inversePrimary: Color(0xFF345BC7),
  ),
  AppPalette.forest: AppPaletteColors(
    primary: Color(0xFF8FD5AE),
    onPrimary: Color(0xFF0B3A25),
    primaryContainer: Color(0xFF24513B),
    onPrimaryContainer: Color(0xFFDDF3E6),
    inversePrimary: Color(0xFF1F6B45),
  ),
  AppPalette.violet: AppPaletteColors(
    primary: Color(0xFFD6B8FF),
    onPrimary: Color(0xFF2C1647),
    primaryContainer: Color(0xFF4A2C6B),
    onPrimaryContainer: Color(0xFFF0E4FF),
    inversePrimary: Color(0xFF6B3FA0),
  ),
  AppPalette.sunset: AppPaletteColors(
    primary: Color(0xFFFFB59A),
    onPrimary: Color(0xFF5A2410),
    primaryContainer: Color(0xFF7A3A22),
    onPrimaryContainer: Color(0xFFFFE3D3),
    inversePrimary: Color(0xFFA8431A),
  ),
  AppPalette.softPink: AppPaletteColors(
    primary: Color(0xFFFFB1CC),
    onPrimary: Color(0xFF5C1734),
    primaryContainer: Color(0xFF7A2D4B),
    onPrimaryContainer: Color(0xFFFFE1EC),
    inversePrimary: Color(0xFFA63D63),
  ),
  AppPalette.graphite: AppPaletteColors(
    primary: Color(0xFFC7CFDD),
    onPrimary: Color(0xFF252B36),
    primaryContainer: Color(0xFF3A4353),
    onPrimaryContainer: Color(0xFFE7EAF0),
    inversePrimary: Color(0xFF3F4756),
  ),
};
