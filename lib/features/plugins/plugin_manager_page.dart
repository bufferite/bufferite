import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_error.dart';
import '../../core/plugin/installed_plugin.dart';
import '../../core/plugin/plugin_permission.dart';
import '../../core/plugin/semantic_version.dart';
import '../../core/ui/components/app_badge.dart';
import '../../core/ui/components/app_toast.dart';
import '../../core/ui/components/empty_state.dart';
import '../../core/ui/components/permission_dialog.dart';
import '../../core/ui/design_tokens.dart';
import 'plugin_actions.dart';
import 'plugin_detail_page.dart';
import 'plugin_providers.dart';
import 'plugin_sideload.dart';

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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: OutlinedButton(
              onPressed: () => _sideload(context, ref),
              child: const Text('Instal dari file'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              0,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: OutlinedButton(
              onPressed: () => _showCatalogInfo(context),
              child: const Text('Buka katalog'),
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
                    _tile(context, ref, items[index], appVersion),
              ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
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
        trailing: PopupMenuButton<String>(
          tooltip: 'Aksi plugin',
          onSelected: (value) {
            if (value == 'toggle') {
              _toggleEnabled(context, ref, plugin);
            } else if (value == 'remove') {
              _confirmRemove(context, ref, plugin);
            }
          },
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'toggle',
              child: Text(plugin.enabled ? 'Nonaktifkan' : 'Aktifkan'),
            ),
            const PopupMenuItem<String>(value: 'remove', child: Text('Hapus')),
          ],
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

  Future<void> _toggleEnabled(
    BuildContext context,
    WidgetRef ref,
    InstalledPlugin plugin,
  ) async {
    final target = !plugin.enabled;
    final ok = await ref
        .read(pluginActionsProvider)
        .setEnabled(plugin.pluginId, target);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: ok
          ? (target ? 'Plugin diaktifkan' : 'Plugin dinonaktifkan')
          : 'Plugin tidak ditemukan',
      tone: ok ? AppToastTone.success : AppToastTone.error,
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    InstalledPlugin plugin,
  ) async {
    final isCore = plugin.pluginId == corePluginId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCore ? 'Hapus plugin core?' : 'Hapus plugin?'),
        content: Text(
          isCore
              ? 'Plugin core menyediakan operasi bawaan. Menghapusnya membuat '
                    'operasi inti tidak tersedia sampai direinstalasi.'
              : '"${plugin.manifest.name}" akan dihapus.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) {
      return;
    }
    final ok = await ref.read(pluginActionsProvider).remove(plugin.pluginId);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: ok ? 'Plugin dihapus' : 'Plugin tidak ditemukan',
      tone: ok ? AppToastTone.success : AppToastTone.error,
    );
  }

  Future<void> _showCatalogInfo(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buka katalog plugin?'),
        content: const Text(
          'Katalog memerlukan akses internet. Bufferite tetap offline untuk '
          'data dan resepmu; hanya katalog yang memakai jaringan.\n\n'
          'Katalog belum tersedia sampai registry Fase 2 dirilis.',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _sideload(BuildContext context, WidgetRef ref) async {
    final service = ref.read(pluginSideloadProvider);
    try {
      final package = await service.pick();
      if (package == null || !context.mounted) {
        return;
      }
      final manifest = package.manifest;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Instal plugin?'),
          content: Text(
            '${manifest.name} v${manifest.version}\n'
            '${manifest.pluginId}\n'
            'Izin: ${manifest.permissions.map((p) => p.wireName).join(', ')}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Instal'),
            ),
          ],
        ),
      );
      if (!(confirmed ?? false) || !context.mounted) {
        return;
      }

      final requested = manifest.permissions
          .where((permission) => permission != PluginPermission.cpu)
          .toSet();
      if (requested.isNotEmpty) {
        final granted = await showPermissionDialog(
          context,
          pluginName: manifest.name,
          permissions: requested,
        );
        if (!granted || !context.mounted) {
          return;
        }
      }

      final plugin = await service.install(package);
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: '${plugin.manifest.name} terpasang',
        tone: AppToastTone.success,
      );
    } on AppError catch (error) {
      if (context.mounted) {
        showAppToast(context, message: error.message, tone: AppToastTone.error);
      }
    } on Object catch (error) {
      if (context.mounted) {
        showAppToast(
          context,
          message: 'Gagal memasang plugin: $error',
          tone: AppToastTone.error,
        );
      }
    }
  }
}
