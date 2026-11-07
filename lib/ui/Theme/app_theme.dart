import 'package:flutter/material.dart';

class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  final Color successContainer;
  final Color onSuccessContainer;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color infoContainer;
  final Color onInfoContainer;

  @override
  AppStatusColors copyWith({
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? infoContainer,
    Color? onInfoContainer,
  }) => AppStatusColors(
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    infoContainer: infoContainer ?? this.infoContainer,
    onInfoContainer: onInfoContainer ?? this.onInfoContainer,
  );

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static const _lightScheme = ColorScheme.light(
    primary: Color(0xFF345BC7),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3EAFF),
    onPrimaryContainer: Color(0xFF203A78),
    secondary: Color(0xFF345BC7),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE3EAFF),
    onSecondaryContainer: Color(0xFF203A78),
    tertiary: Color(0xFF345BC7),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE3EAFF),
    onTertiaryContainer: Color(0xFF203A78),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE4E2),
    onErrorContainer: Color(0xFFB42318),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF20242C),
    onSurfaceVariant: Color(0xFF596273),
    outline: Color(0xFF737E8E),
    outlineVariant: Color(0xFFDDE2EA),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF0F2F5),
    surfaceContainer: Color(0xFFF0F2F5),
    surfaceContainerHigh: Color(0xFFE8ECF2),
    surfaceContainerHighest: Color(0xFFE8ECF2),
    inverseSurface: Color(0xFF20242C),
    onInverseSurface: Color(0xFFF7F8FA),
    inversePrimary: Color(0xFFADC6FF),
    surfaceTint: Colors.transparent,
  );

  static const _darkScheme = ColorScheme.dark(
    primary: Color(0xFFADC6FF),
    onPrimary: Color(0xFF172B55),
    primaryContainer: Color(0xFF2B3D62),
    onPrimaryContainer: Color(0xFFE3EAFF),
    secondary: Color(0xFFADC6FF),
    onSecondary: Color(0xFF172B55),
    secondaryContainer: Color(0xFF2B3D62),
    onSecondaryContainer: Color(0xFFE3EAFF),
    tertiary: Color(0xFFADC6FF),
    onTertiary: Color(0xFF172B55),
    tertiaryContainer: Color(0xFF2B3D62),
    onTertiaryContainer: Color(0xFFE3EAFF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF542C2B),
    errorContainer: Color(0xFF542C2B),
    onErrorContainer: Color(0xFFFFB4AB),
    surface: Color(0xFF202329),
    onSurface: Color(0xFFEDF0F5),
    onSurfaceVariant: Color(0xFFB3BDCC),
    outline: Color(0xFF818D9F),
    outlineVariant: Color(0xFF3C4451),
    surfaceContainerLowest: Color(0xFF181A1F),
    surfaceContainerLow: Color(0xFF252932),
    surfaceContainer: Color(0xFF252932),
    surfaceContainerHigh: Color(0xFF2C313B),
    surfaceContainerHighest: Color(0xFF2C313B),
    inverseSurface: Color(0xFFF7F8FA),
    onInverseSurface: Color(0xFF20242C),
    inversePrimary: Color(0xFF345BC7),
    surfaceTint: Colors.transparent,
  );

  static final ThemeData light = _build(
    scheme: _lightScheme,
    scaffold: const Color(0xFFF7F8FA),
    card: const Color(0xFFFFFFFF),
    divider: const Color(0xFFDDE2EA),
    status: const AppStatusColors(
      successContainer: Color(0xFFE6F4EA),
      onSuccessContainer: Color(0xFF21683D),
      warningContainer: Color(0xFFFFF0CC),
      onWarningContainer: Color(0xFF785100),
      infoContainer: Color(0xFFE3EAFF),
      onInfoContainer: Color(0xFF345BC7),
    ),
  );

  static final ThemeData dark = _build(
    scheme: _darkScheme,
    scaffold: const Color(0xFF181A1F),
    card: const Color(0xFF202329),
    divider: const Color(0xFF3C4451),
    status: const AppStatusColors(
      successContainer: Color(0xFF233D2F),
      onSuccessContainer: Color(0xFF92D6AD),
      warningContainer: Color(0xFF423821),
      onWarningContainer: Color(0xFFF2CC78),
      infoContainer: Color(0xFF2B3D62),
      onInfoContainer: Color(0xFFADC6FF),
    ),
  );

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
    required Color divider,
    required AppStatusColors status,
  }) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    cardColor: card,
    dividerColor: divider,
    extensions: [status],
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 24 / 16),
      bodyMedium: TextStyle(fontSize: 14, height: 20 / 14),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(fontSize: 12, height: 16 / 12),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
