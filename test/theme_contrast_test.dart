import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_mobile_app/ui/Theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  for (final entry in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    final theme = entry.value;
    final scheme = theme.colorScheme;
    final status = theme.extension<AppStatusColors>()!;
    final surfaces = {
      'scaffold': theme.scaffoldBackgroundColor,
      'surface': scheme.surface,
      'surfaceContainerLow': scheme.surfaceContainerLow,
      'surfaceContainerHigh': scheme.surfaceContainerHigh,
    };

    group('${entry.key} theme contrast', () {
      test('body text meets 4.5:1 on every surface', () {
        for (final surface in surfaces.entries) {
          expect(
            _contrast(scheme.onSurface, surface.value),
            greaterThanOrEqualTo(4.5),
            reason: 'onSurface on ${surface.key}',
          );
          expect(
            _contrast(scheme.onSurfaceVariant, surface.value),
            greaterThanOrEqualTo(4.5),
            reason: 'onSurfaceVariant on ${surface.key}',
          );
          expect(
            _contrast(scheme.primary, surface.value),
            greaterThanOrEqualTo(4.5),
            reason: 'primary text on ${surface.key}',
          );
          expect(
            _contrast(scheme.error, surface.value),
            greaterThanOrEqualTo(4.5),
            reason: 'error text on ${surface.key}',
          );
        }
      });

      test('filled controls and containers meet 4.5:1', () {
        final pairs = {
          'onPrimary on primary': (scheme.onPrimary, scheme.primary),
          'onPrimaryContainer on primaryContainer': (
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
          ),
          'onError on error': (scheme.onError, scheme.error),
          'onErrorContainer on errorContainer': (
            scheme.onErrorContainer,
            scheme.errorContainer,
          ),
          'success': (status.onSuccessContainer, status.successContainer),
          'warning': (status.onWarningContainer, status.warningContainer),
          'info': (status.onInfoContainer, status.infoContainer),
        };
        for (final pair in pairs.entries) {
          expect(
            _contrast(pair.value.$1, pair.value.$2),
            greaterThanOrEqualTo(4.5),
            reason: pair.key,
          );
        }
      });

      test('control boundaries and focus ring meet 3:1', () {
        final decoration = theme.inputDecorationTheme;
        final fill = decoration.fillColor!;
        final borders = {
          'enabled': decoration.enabledBorder as OutlineInputBorder,
          'focused': decoration.focusedBorder as OutlineInputBorder,
          'error': decoration.errorBorder as OutlineInputBorder,
        };
        for (final border in borders.entries) {
          for (final surface in [
            fill,
            scheme.surface,
            scheme.surfaceContainerHigh,
          ]) {
            expect(
              _contrast(border.value.borderSide.color, surface),
              greaterThanOrEqualTo(3),
              reason: '${border.key} border on $surface',
            );
          }
        }
      });
    });
  }
}
