import 'dart:io';

import 'package:flutter/material.dart';

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
                const AppBadge(label: 'unverified', tone: AppBadgeTone.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, 'Manifest'),
          _kv('ID', manifest.pluginId),
          _kv('Versi', manifest.version.toString()),
          _kv('Min. app', manifest.minAppVersion.toString()),
          _kv('Entrypoint', manifest.entrypoint),
          _kv('Ukuran', _sizeLabel()),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, 'Izin'),
          if (manifest.permissions.isEmpty)
            const Text('Tidak ada izin tambahan.')
          else
            for (final permission in manifest.permissions)
              _kv('•', permission.wireName),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, 'Operasi (${manifest.operations.length})'),
          for (final operation in manifest.operations)
            _kv(operation.id, operation.category.label),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, 'Integritas'),
          _kv('SHA-256', manifest.integritySha256 ?? 'tidak ditandatangani'),
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

  String _sizeLabel() {
    final path = plugin.installPath;
    if (path == null) {
      return 'tidak diketahui';
    }
    final directory = Directory(path);
    if (!directory.existsSync()) {
      return 'tidak ditemukan';
    }
    var total = 0;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is File) {
        total += entity.lengthSync();
      }
    }
    return '$total byte';
  }
}
