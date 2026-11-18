import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/bootstrap/bootstrap_provider.dart';
import '../../core/bootstrap/core_bootstrap_service.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/ui/components/app_toast.dart';
import '../../core/ui/design_tokens.dart';
import '../../core/ui/theme_provider.dart';
import '../operations/operation_providers.dart';
import '../plugins/plugin_manager_service.dart';
import '../plugins/plugin_providers.dart';
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
          const SizedBox(height: AppSpacing.xl),
          Text('Privasi & Log', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ikut serta kirim log eksekusi'),
            subtitle: const Text(
              'Default mati. Log tidak pernah dikirim tanpa izin.',
            ),
            value: settings.optInLogging,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setOptInLogging(value),
          ),
          OutlinedButton.icon(
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus log'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Tentang', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Bufferite'),
            subtitle: Text('Versi 1.0.0 · Lisensi MIT'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Privasi'),
            subtitle: Text(
              'Offline-first. Data dan resep tidak keluar dari perangkat; '
              'hanya katalog plugin Fase 2 yang memakai jaringan.',
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Kode sumber'),
            subtitle: Text('github.com/bufferite/bufferite'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Data', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _reinstallCore,
            icon: const Icon(Icons.refresh),
            label: const Text('Instal ulang core.berp'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _resetData,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Reset data'),
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

  Future<void> _clearLogs() async {
    try {
      final support = await getApplicationSupportDirectory();
      final logs = Directory('${support.path}/logs');
      if (logs.existsSync()) {
        logs.deleteSync(recursive: true);
      }
      if (mounted) {
        showAppToast(
          context,
          message: 'Log dihapus',
          tone: AppToastTone.success,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: 'Gagal menghapus log: $error',
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> _reinstallCore() async {
    final confirmed = await _confirm(
      'Instal ulang core.berp?',
      'Bootstrap dijalankan ulang dan operasi inti dipasang kembali bila aset '
          'tersedia.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(coreBootstrapServiceProvider).installBundledCore();
      await ref.read(pluginManagerServiceProvider).restore();
      ref.invalidate(coreBootstrapProvider);
      ref.invalidate(installedPluginsProvider);
      ref.read(operationsRevisionProvider.notifier).bump();
      if (mounted) {
        showAppToast(
          context,
          message: 'Core.berp dipasang ulang',
          tone: AppToastTone.success,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: 'Gagal memasang ulang core: $error',
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> _resetData() async {
    final confirmed = await _confirm(
      'Reset data?',
      'Semua recipe, plugin, dan pengaturan akan dihapus. Tindakan ini tidak '
          'dapat dibatalkan.',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      final support = await getApplicationSupportDirectory();
      for (final name in <String>['plugins', 'logs']) {
        final directory = Directory('${support.path}/$name');
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      }
      await ref.read(appDatabaseProvider).close();
      final path = '${await getDatabasesPath()}/${AppDatabase.defaultFileName}';
      await databaseFactory.deleteDatabase(path);
      if (mounted) {
        showAppToast(
          context,
          message: 'Data direset',
          tone: AppToastTone.success,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: 'Gagal reset data: $error',
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<bool> _confirm(
    String title,
    String body, {
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
