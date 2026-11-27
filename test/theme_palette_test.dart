import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mobile_app/Home/navbar_page.dart';
import 'package:my_mobile_app/ui/Theme/app_palette.dart';
import 'package:my_mobile_app/ui/Theme/app_theme.dart';
import 'package:my_mobile_app/ui/Theme/theme_notifier.dart';
import 'package:my_mobile_app/ui/Theme/theme_tonggle.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeNotifier.themeMode.value = ThemeMode.light;
    ThemeNotifier.palette.value = AppPalette.ocean;
    ThemeNotifier.brand.value = AppBrandMark.logo;
  });

  test(
    'missing or unknown palette and brand preferences use defaults',
    () async {
      SharedPreferences.setMockInitialValues({
        'APP_THEME_PALETTE': 'unknown',
        'APP_BRAND': 'unknown',
      });

      await ThemeNotifier.initialize();

      expect(ThemeNotifier.palette.value, AppPalette.ocean);
      expect(ThemeNotifier.brand.value, AppBrandMark.logo);
    },
  );

  test('palette and brand preferences survive a restart', () async {
    await ThemeNotifier.setPalette(AppPalette.violet);
    await ThemeNotifier.setBrand(AppBrandMark.layers);

    ThemeNotifier.palette.value = AppPalette.ocean;
    ThemeNotifier.brand.value = AppBrandMark.logo;
    await ThemeNotifier.initialize();

    expect(ThemeNotifier.palette.value, AppPalette.violet);
    expect(ThemeNotifier.brand.value, AppBrandMark.layers);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('APP_THEME_PALETTE'), 'violet');
    expect(preferences.getString('APP_BRAND'), 'layers');
  });

  test('every palette exposes matching light and dark themes', () {
    for (final palette in AppPalette.values) {
      expect(
        AppTheme.lightFor(palette).brightness,
        Brightness.light,
        reason: '${palette.name} light brightness',
      );
      expect(
        AppTheme.darkFor(palette).brightness,
        Brightness.dark,
        reason: '${palette.name} dark brightness',
      );
      expect(
        AppTheme.lightFor(palette).colorScheme.primary,
        palette.light.primary,
        reason: '${palette.name} light primary',
      );
      expect(
        AppTheme.darkFor(palette).colorScheme.primary,
        palette.dark.primary,
        reason: '${palette.name} dark primary',
      );
    }
  });

  testWidgets('appearance dialog exposes and persists palette and brand', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ThemeToggle())),
      ),
    );
    await tester.tap(find.byTooltip('Pilih tema'));
    await tester.pumpAndSettle();

    expect(find.text('Tampilan'), findsOneWidget);
    expect(find.text('Palet warna'), findsOneWidget);
    expect(find.text('Simbol aplikasi'), findsOneWidget);

    final forest = find.byKey(const ValueKey('palette-forest'));
    expect(forest, findsOneWidget);
    final targetSize = tester.getSize(forest);
    expect(targetSize.width, greaterThanOrEqualTo(48));
    expect(targetSize.height, greaterThanOrEqualTo(48));

    await tester.tap(forest);
    await tester.pumpAndSettle();
    expect(ThemeNotifier.palette.value, AppPalette.forest);

    await tester.ensureVisible(find.byKey(const ValueKey('brand-rocket')));
    await tester.tap(find.byKey(const ValueKey('brand-rocket')));
    await tester.pumpAndSettle();
    expect(ThemeNotifier.brand.value, AppBrandMark.rocket);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('APP_THEME_PALETTE'), 'forest');
    expect(preferences.getString('APP_BRAND'), 'rocket');
  });

  testWidgets('appearance dialog fits a narrow screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(body: Center(child: ThemeToggle())),
      ),
    );
    await tester.tap(find.byTooltip('Pilih tema'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tampilan'), findsOneWidget);
    await tester.ensureVisible(find.text('Selesai'));
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tampilan'), findsNothing);
  });

  testWidgets('navbar renders the selected brand mark', (tester) async {
    ThemeNotifier.brand.value = AppBrandMark.rocket;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(appBar: Navbar())),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
  });
}
