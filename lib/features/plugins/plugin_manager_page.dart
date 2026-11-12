import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plugin/installed_plugin.dart';
import '../../core/plugin/semantic_version.dart';
import '../../core/ui/components/app_badge.dart';
import '../../core/ui/components/empty_state.dart';
import '../../core/ui/design_tokens.dart';
import 'plugin_detail_page.dart';
import 'plugin_providers.dart';

/// Daftar plugin terpasang sesuai `DESIGN.md` §6.5.
class PluginManagerPage extends ConsumerWidget {
  const PluginManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appVersion = ref.watch(appVersionProvider);
    final plugins = ref.watch(installedPluginsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin Manager'),
        actions: <Widget>[
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: OutlinedButton(
              onPressed: null,
              child: Text('Instal dari file'),
            ),
          ),
        ],
      ),
      body: plugins.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat plugin',
          description: error.toString(),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.extension_outlined,
                title: 'Belum ada plugin terpasang',
                description:
                    'Instal plugin dari file .berp (sideload) atau buka '
                    'katalog saat tersedia.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    _tile(context, items[index], appVersion),
              ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    InstalledPlugin plugin,
    SemanticVersion appVersion,
  ) {
    final manifest = plugin.manifest;
    final status = plugin.statusFor(appVersion);
    return Card(
      child: ListTile(
        title: Text(manifest.name),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => PluginDetailPage(plugin: plugin),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${manifest.pluginId} · v${manifest.version}'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sumber: ${plugin.source.name} · Izin: '
              '${manifest.permissions.map((p) => p.wireName).join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                AppBadge(label: manifest.tier.name),
                _statusBadge(status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(PluginStatus status) {
    return switch (status) {
      PluginStatus.active => const AppBadge(
        label: 'aktif',
        tone: AppBadgeTone.success,
      ),
      PluginStatus.disabled => const AppBadge(label: 'nonaktif'),
      PluginStatus.unverified => const AppBadge(
        label: 'unverified',
        tone: AppBadgeTone.warning,
      ),
      PluginStatus.incompatible => const AppBadge(
        label: 'inkompatibel',
        tone: AppBadgeTone.danger,
      ),
    };
  }
}
