import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'theme_notifier.dart';

/// Renders the user-selected in-app brand mark.
///
/// The default option keeps the shipped logo; the other options use Material
/// icons so no extra image assets are required. This does not change the
/// Android launcher icon, which is a native resource.
class AppBrandMarkView extends StatelessWidget {
  const AppBrandMarkView({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppBrandMark>(
      valueListenable: ThemeNotifier.brand,
      builder: (context, brand, child) {
        if (brand.usesLogoAsset) {
          return Image.asset(
            'assets/PM_Logo.png',
            width: size,
            height: size,
            cacheWidth: (size * 4).round(),
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.business,
                color: Theme.of(context).colorScheme.primary,
                size: size * 0.85,
              );
            },
          );
        }
        final colors = Theme.of(context).colorScheme;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Icon(
            brand.icon,
            size: size * 0.62,
            color: colors.onPrimaryContainer,
          ),
        );
      },
    );
  }
}
