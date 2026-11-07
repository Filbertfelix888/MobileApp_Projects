import 'package:flutter/material.dart';

import 'theme_notifier.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        padding: EdgeInsets.zero,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      iconSize: 20,
      icon: const Icon(Icons.brightness_auto_outlined),
      tooltip: 'Pilih tema',
      onPressed: () async {
        final mode = await showDialog<ThemeMode>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: const Text('Tampilan'),
            children: [
              RadioGroup<ThemeMode>(
                groupValue: ThemeNotifier.themeMode.value,
                onChanged: (value) {
                  if (value != null) Navigator.pop(dialogContext, value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in ThemeMode.values)
                      RadioListTile<ThemeMode>(
                        value: option,
                        title: Text(_themeLabel(option)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (mode == null || !context.mounted) return;
        try {
          await ThemeNotifier.setThemeMode(mode);
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
  }
}

String _themeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Sistem',
  ThemeMode.light => 'Terang',
  ThemeMode.dark => 'Gelap',
};
