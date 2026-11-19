import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/bootstrap/bootstrap_provider.dart';
import '../../core/bootstrap/core_bootstrap_service.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/language_provider.dart';
import '../../core/i18n/localized_error.dart';
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
    final language =
        ref.watch(languageProvider).asData?.value ?? AppLanguage.indonesian;

    if (!_initialized) {
      _timeoutController.text = settings.stepTimeout.inMilliseconds.toString();
      _memoryController.text = (settings.memoryLimitBytes ~/ (1024 * 1024))
          .toString();
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(context.tr('settings.appearance'), style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<AppThemeMode>(
            segments: <ButtonSegment<AppThemeMode>>[
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.system,
                label: Text(context.tr('settings.themeSystem')),
                icon: const Icon(Icons.brightness_auto),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.light,
                label: Text(context.tr('settings.themeLight')),
                icon: const Icon(Icons.light_mode),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.dark,
                label: Text(context.tr('settings.themeDark')),
                icon: const Icon(Icons.dark_mode),
              ),
            ],
            selected: <AppThemeMode>{mode},
            onSelectionChanged: (selection) {
              ref.read(themeModeProvider.notifier).setMode(selection.first);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.tr('settings.languageLabel'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<AppLanguage>(
            segments: <ButtonSegment<AppLanguage>>[
              ButtonSegment<AppLanguage>(
                value: AppLanguage.indonesian,
                label: Text(context.tr('settings.languageIndonesian')),
              ),
              ButtonSegment<AppLanguage>(
                value: AppLanguage.english,
                label: Text(context.tr('settings.languageEnglish')),
              ),
            ],
            selected: <AppLanguage>{language},
            onSelectionChanged: (selection) {
              ref
                  .read(languageProvider.notifier)
                  .setLanguage(selection.first);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(context.tr('settings.sandbox'), style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _timeoutController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('settings.timeoutLabel'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _memoryController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('settings.memoryLabel'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saveLimits,
            child: Text(context.tr('settings.saveLimits')),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            context.tr('settings.privacyLogs'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('settings.optIn')),
            subtitle: Text(context.tr('settings.optInSubtitle')),
            value: settings.optInLogging,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setOptInLogging(value),
          ),
          OutlinedButton.icon(
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_outline),
            label: Text(context.tr('settings.clearLogs')),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(context.tr('settings.about'), style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bufferite'),
            subtitle: Text(
              context.tr('settings.version', args: <String, Object?>{
                'version': '1.0.0',
              }),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('settings.privacy')),
            subtitle: Text(context.tr('settings.privacyBody')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('settings.sourceCode')),
            subtitle: const Text('github.com/bufferite/bufferite'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(context.tr('settings.data'), style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _reinstallCore,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('settings.reinstallCore')),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _resetData,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_forever),
            label: Text(context.tr('settings.resetData')),
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
        message: context.tr('settings.invalidLimits'),
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
        message: context.tr('settings.limitsSaved'),
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
          message: context.tr('settings.logsCleared'),
          tone: AppToastTone.success,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: context.tr(
            'settings.logsClearFailed',
            args: <String, Object?>{'error': context.trErrorObject(error)},
          ),
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> _reinstallCore() async {
    final confirmed = await _confirm(
      context.tr('settings.reinstallTitle'),
      context.tr('settings.reinstallBody'),
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
          message: context.tr('settings.reinstalled'),
          tone: AppToastTone.success,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: context.tr(
            'settings.reinstallFailed',
            args: <String, Object?>{'error': context.trErrorObject(error)},
          ),
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> _resetData() async {
    final confirmed = await _confirm(
      context.tr('settings.resetTitle'),
      context.tr('settings.resetBody'),
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
          message: context.tr('settings.resetDone'),
          tone: AppToastTone.success,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: context.tr(
            'settings.resetFailed',
            args: <String, Object?>{'error': context.trErrorObject(error)},
          ),
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
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('common.continue')),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
