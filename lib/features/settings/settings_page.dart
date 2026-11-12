import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/design_tokens.dart';
import '../../core/ui/theme_provider.dart';
import 'settings_repository.dart';

/// Tab Settings. F12-T01: pilihan tema persisten.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode =
        ref.watch(themeModeProvider).asData?.value ?? AppThemeMode.system;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text('Tampilan', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<AppThemeMode>(
            segments: const <ButtonSegment<AppThemeMode>>[
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.system,
                label: Text('Sistem'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.light,
                label: Text('Terang'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.dark,
                label: Text('Gelap'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: <AppThemeMode>{mode},
            onSelectionChanged: (selection) {
              ref.read(themeModeProvider.notifier).setMode(selection.first);
            },
          ),
        ],
      ),
    );
  }
}
