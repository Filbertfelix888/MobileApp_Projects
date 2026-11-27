import 'dart:async';

import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'theme_notifier.dart';

/// Appearance settings dialog: mode, accent palette, and in-app brand mark.
///
/// Changes apply immediately so the user can preview them. Each choice is
/// persisted independently; a failed write keeps the new value in memory and
/// warns that it may revert after a restart.
class AppearanceDialog extends StatelessWidget {
  const AppearanceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Tampilan', style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const _SectionTitle('Mode'),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeNotifier.themeMode,
                builder: (context, mode, child) {
                  return RadioGroup<ThemeMode>(
                    groupValue: mode,
                    onChanged: (value) {
                      if (value == null) return;
                      unawaited(
                        _apply(
                          context,
                          () => ThemeNotifier.setThemeMode(value),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final option in ThemeMode.values)
                          RadioListTile<ThemeMode>(
                            value: option,
                            title: Text(_modeLabel(option)),
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const _SectionTitle('Palet warna'),
              ValueListenableBuilder<AppPalette>(
                valueListenable: ThemeNotifier.palette,
                builder: (context, selected, child) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in AppPalette.values)
                        _PaletteOption(
                          key: ValueKey('palette-${option.name}'),
                          palette: option,
                          selected: option == selected,
                          onTap: () {
                            unawaited(
                              _apply(
                                context,
                                () => ThemeNotifier.setPalette(option),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              const _SectionTitle('Simbol aplikasi'),
              ValueListenableBuilder<AppBrandMark>(
                valueListenable: ThemeNotifier.brand,
                builder: (context, selected, child) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in AppBrandMark.values)
                        ChoiceChip(
                          key: ValueKey('brand-${option.name}'),
                          selected: option == selected,
                          onSelected: (isSelected) {
                            if (!isSelected) return;
                            unawaited(
                              _apply(
                                context,
                                () => ThemeNotifier.setBrand(option),
                              ),
                            );
                          },
                          avatar: Icon(option.icon, size: 18),
                          label: Text(option.label),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PaletteOption extends StatelessWidget {
  const _PaletteOption({
    super.key,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Palet ${palette.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: palette.swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outlineVariant),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  palette.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check, size: 16, color: colors.onPrimaryContainer),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _apply(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Tampilan berubah, tetapi gagal disimpan dan dapat kembali setelah aplikasi dibuka ulang.',
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

String _modeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Sistem',
  ThemeMode.light => 'Terang',
  ThemeMode.dark => 'Gelap',
};
