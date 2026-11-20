import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/localized_error.dart';
import '../../core/i18n/operation_localization.dart';
import '../../core/plugin/installed_plugin.dart';
import '../../core/ui/components/app_badge.dart';
import '../../core/ui/components/app_toast.dart';
import '../../core/ui/design_tokens.dart';
import '../operations/operation_providers.dart';
import 'plugin_manager_service.dart';
import 'plugin_providers.dart';

/// Halaman detail plugin: manifest, izin, operasi, ukuran, sumber, rollback.
class PluginDetailPage extends ConsumerStatefulWidget {
  const PluginDetailPage({super.key, required this.plugin});

  final InstalledPlugin plugin;

  @override
  ConsumerState<PluginDetailPage> createState() => _PluginDetailPageState();
}

class _PluginDetailPageState extends ConsumerState<PluginDetailPage> {
  late InstalledPlugin _plugin;
  bool _rollingBack = false;

  @override
  void initState() {
    super.initState();
    _plugin = widget.plugin;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manifest = _plugin.manifest;
    final previousVersion = _plugin.provenance?.previousVersion;

    return Scaffold(
      appBar: AppBar(title: Text(manifest.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              AppBadge(label: manifest.tier.name),
              AppBadge(label: _plugin.source.name),
              if (!_plugin.verified)
                AppBadge(
                  label: context.tr('common.unverified'),
                  tone: AppBadgeTone.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, context.tr('plugins.detail.manifest')),
          _kv(context.tr('plugins.detail.id'), manifest.pluginId),
          _kv(
            context.tr('plugins.detail.version'),
            manifest.version.toString(),
          ),
          _kv(
            context.tr('plugins.detail.minApp'),
            manifest.minAppVersion.toString(),
          ),
          _kv(context.tr('plugins.detail.entrypoint'), manifest.entrypoint),
          _kv(context.tr('plugins.detail.size'), _sizeLabel(context)),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, context.tr('plugins.detail.permissions')),
          if (manifest.permissions.isEmpty)
            Text(context.tr('plugins.detail.noExtraPermissions'))
          else
            for (final permission in manifest.permissions)
              _kv('•', permission.wireName),
          const SizedBox(height: AppSpacing.lg),
          _section(
            theme,
            context.tr(
              'plugins.detail.operations',
              args: <String, Object?>{'count': manifest.operations.length},
            ),
          ),
          for (final operation in manifest.operations)
            _kv(
              operation.id,
              operationCategoryLabel(context, operation.category),
            ),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, context.tr('plugins.detail.integrity')),
          _kv(
            'SHA-256',
            manifest.integritySha256 ?? context.tr('plugins.detail.unsigned'),
          ),
          if (previousVersion != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _section(theme, context.tr('plugins.detail.rollback')),
            Text(
              context.tr(
                'plugins.detail.rollbackHint',
                args: <String, Object?>{'version': previousVersion},
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _rollingBack ? null : _rollback,
              icon: _rollingBack
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.undo),
              label: Text(
                context.tr(
                  'plugins.detail.rollbackAction',
                  args: <String, Object?>{'version': previousVersion},
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rollback() async {
    final previousVersion = _plugin.provenance?.previousVersion;
    if (previousVersion == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('plugins.rollbackTitle')),
        content: Text(
          context.tr(
            'plugins.rollbackBody',
            args: <String, Object?>{
              'name': _plugin.manifest.name,
              'installed': _plugin.version,
              'version': previousVersion,
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('plugins.rollbackConfirm')),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    setState(() => _rollingBack = true);
    try {
      final restored = await ref
          .read(pluginManagerServiceProvider)
          .rollback(_plugin.pluginId);
      ref.invalidate(installedPluginsProvider);
      ref.read(operationsRevisionProvider.notifier).bump();
      if (!mounted) {
        return;
      }
      setState(() => _plugin = restored);
      showAppToast(
        context,
        message: context.tr(
          'plugins.rollbackSuccess',
          args: <String, Object?>{'version': restored.version},
        ),
        tone: AppToastTone.success,
      );
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: context.tr(
            'plugins.rollbackFailed',
            args: <String, Object?>{'error': context.trErrorObject(error)},
          ),
          tone: AppToastTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _rollingBack = false);
      }
    }
  }

  Widget _section(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(title, style: theme.textTheme.titleLarge),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _sizeLabel(BuildContext context) {
    final path = _plugin.installPath;
    if (path == null) {
      return context.tr('plugins.detail.unknown');
    }
    final directory = Directory(path);
    if (!directory.existsSync()) {
      return context.tr('plugins.detail.notFound');
    }
    var total = 0;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is File) {
        total += entity.lengthSync();
      }
    }
    return context.trPlural('common.bytes', total);
  }
}
