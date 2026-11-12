import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/components/app_toast.dart';
import '../../core/ui/design_tokens.dart';
import '../../core/ui/theme_provider.dart';
import 'settings_provider.dart';
import 'settings_repository.dart';

/// Tab Settings. F12: tema, batas sandbox, dan log.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _timeoutController = TextEditingController();
  final TextEditingController _memoryController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _timeoutController.dispose();
    _memoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode =
        ref.watch(themeModeProvider).asData?.value ?? AppThemeMode.system;
    final settings =
        ref.watch(settingsProvider).asData?.value ?? AppSettings.defaults;

    if (!_initialized) {
      _timeoutController.text = settings.stepTimeout.inMilliseconds.toString();
      _memoryController.text = (settings.memoryLimitBytes ~/ (1024 * 1024))
          .toString();
      _initialized = true;
    }

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
          const SizedBox(height: AppSpacing.xl),
          Text('Sandbox', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _timeoutController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Batas waktu per operasi (ms)',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _memoryController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Batas memori (MiB)'),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saveLimits,
            child: const Text('Simpan batas sandbox'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLimits() async {
    final timeoutMs = int.tryParse(_timeoutController.text.trim());
    final memoryMib = int.tryParse(_memoryController.text.trim());
    if (timeoutMs == null ||
        timeoutMs <= 0 ||
        memoryMib == null ||
        memoryMib <= 0) {
      showAppToast(
        context,
        message: 'Nilai batas harus angka positif.',
        tone: AppToastTone.error,
      );
      return;
    }

    final controller = ref.read(settingsProvider.notifier);
    await controller.setStepTimeout(Duration(milliseconds: timeoutMs));
    await controller.setMemoryLimitBytes(memoryMib * 1024 * 1024);
    if (mounted) {
      showAppToast(
        context,
        message: 'Batas sandbox disimpan',
        tone: AppToastTone.success,
      );
    }
  }
}
