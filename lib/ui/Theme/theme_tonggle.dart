import 'package:flutter/material.dart';

import 'theme_notifier.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.themeMode,
      builder: (context, currentMode, child) {
        final isDark = currentMode == ThemeMode.dark;
        final colors = Theme.of(context).colorScheme;
        return IconButton(
          style: IconButton.styleFrom(
            minimumSize: const Size.square(48),
            padding: EdgeInsets.zero,
            backgroundColor: colors.surfaceContainerHighest,
            foregroundColor: colors.onSurface,
          ),
          iconSize: 20,
          icon: Icon(
            isDark ? Icons.wb_sunny_outlined : Icons.brightness_2_outlined,
          ),
          tooltip: isDark ? 'Aktifkan tema terang' : 'Aktifkan tema gelap',
          onPressed: () async {
            try {
              await ThemeNotifier.toggleTheme();
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Tema berubah, tetapi gagal disimpan dan dapat kembali setelah aplikasi dibuka ulang.',
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
        );
      },
    );
  }
}
