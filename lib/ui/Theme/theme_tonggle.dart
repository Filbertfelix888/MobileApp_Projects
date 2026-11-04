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

        return Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.brightness_2_outlined,
              color: isDark ? Colors.white : const Color(0xFF111111),
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ThemeNotifier.toggleTheme();
            },
          ),
        );
      },
    );
  }
}