import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/operation_localization.dart';
import '../../core/plugin/installed_plugin.dart';
import '../../core/ui/components/app_badge.dart';
import '../../core/ui/design_tokens.dart';

/// Halaman detail plugin: manifest, izin, operasi, ukuran, sumber.
class PluginDetailPage extends StatelessWidget {
  const PluginDetailPage({super.key, required this.plugin});

  final InstalledPlugin plugin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manifest = plugin.manifest;

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
              AppBadge(label: plugin.source.name),
              if (!plugin.verified)
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
        ],
      ),
    );
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
    final path = plugin.installPath;
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
