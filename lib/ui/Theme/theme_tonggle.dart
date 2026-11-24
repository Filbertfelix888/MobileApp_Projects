import 'package:flutter/material.dart';

import 'appearance_dialog.dart';

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
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (dialogContext) => const AppearanceDialog(),
        );
      },
    );
  }
}
