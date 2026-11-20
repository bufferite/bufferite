import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_error.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/localized_error.dart';
import '../../core/plugin/installed_plugin.dart';
import '../../core/plugin/plugin_permission.dart';
import '../../core/plugin/semantic_version.dart';
import '../../core/registry/registry_plugin_status.dart';
import '../../core/ui/components/app_badge.dart';
import '../../core/ui/components/app_toast.dart';
import '../../core/ui/components/empty_state.dart';
import '../../core/ui/components/permission_dialog.dart';
import '../../core/ui/design_tokens.dart';
import 'plugin_actions.dart';
import 'plugin_detail_page.dart';
import 'plugin_providers.dart';
import 'plugin_sideload.dart';
import 'registry/registry_catalog_screen.dart';
import 'registry/registry_providers.dart';

/// Daftar plugin terpasang sesuai `DESIGN.md` §6.5.
class PluginManagerPage extends ConsumerWidget {
  const PluginManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appVersion = ref.watch(appVersionProvider);
    final plugins = ref.watch(installedPluginsProvider);
    final registryStatuses = ref.watch(registryPluginStatusesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('plugins.title')),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: OutlinedButton(
              onPressed: () => _sideload(context, ref),
              child: Text(context.tr('plugins.installFromFile')),
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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const RegistryCatalogScreen(),
                ),
              ),
              child: Text(context.tr('plugins.openCatalog')),
            ),
          ),
        ],
      ),
      body: plugins.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.error_outline,
          title: context.tr('plugins.loadFailed'),
          description: context.trErrorObject(error),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.extension_outlined,
              title: context.tr('plugins.emptyTitle'),
              description: context.tr('plugins.emptyDescription'),
            );
          }
          final revoked = items
              .where(
                (plugin) =>
                    registryStatuses[plugin.pluginId]?.isRevoked == true,
              )
              .length;
          return Column(
            children: <Widget>[
              if (revoked > 0) _revokedBanner(context, revoked),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _tile(
                    context,
                    ref,
                    items[index],
                    appVersion,
                    registryStatuses[items[index].pluginId],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    InstalledPlugin plugin,
    SemanticVersion appVersion,
    PluginRegistryStatus? registryStatus,
  ) {
    final manifest = plugin.manifest;
    final status = plugin.statusFor(appVersion);
    final registryBadge = registryStatus == null
        ? null
        : _registryBadge(context, registryStatus);
    return Card(
      child: ListTile(
        title: Text(manifest.name),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => PluginDetailPage(plugin: plugin),
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: context.tr('plugins.actions'),
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
              child: Text(
                plugin.enabled
                    ? context.tr('plugins.disable')
                    : context.tr('plugins.enable'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'remove',
              child: Text(context.tr('common.delete')),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${manifest.pluginId} · v${manifest.version}'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr(
                'plugins.sourcePermissions',
                args: <String, Object?>{
                  'source': plugin.source.name,
                  'permissions': manifest.permissions
                      .map((permission) => permission.wireName)
                      .join(', '),
                },
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                AppBadge(label: manifest.tier.name),
                _statusBadge(context, status),
                ?registryBadge,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _revokedBanner(BuildContext context, int count) {
    final theme = Theme.of(context);
    final tone = theme.colorScheme.error;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.gpp_bad_outlined, size: 18, color: tone),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.tr(
                'plugins.revokedBanner',
                args: <String, Object?>{'count': count},
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context, PluginStatus status) {
    return switch (status) {
      PluginStatus.active => AppBadge(
        label: context.tr('plugins.status.active'),
        tone: AppBadgeTone.success,
      ),
      PluginStatus.disabled => AppBadge(
        label: context.tr('plugins.status.disabled'),
      ),
      PluginStatus.unverified => AppBadge(
        label: context.tr('plugins.status.unverified'),
        tone: AppBadgeTone.warning,
      ),
      PluginStatus.incompatible => AppBadge(
        label: context.tr('plugins.status.incompatible'),
        tone: AppBadgeTone.danger,
      ),
    };
  }

  /// Badge registry: revocation lebih penting daripada tawaran update.
  Widget? _registryBadge(BuildContext context, PluginRegistryStatus status) {
    if (status.isRevoked) {
      return AppBadge(
        label: context.tr('plugins.status.revoked'),
        tone: AppBadgeTone.danger,
      );
    }
    final update = status.update;
    if (update != null) {
      return AppBadge(
        label: context.tr(
          'plugins.updateAvailable',
          args: <String, Object?>{'version': update.version},
        ),
        tone: AppBadgeTone.accent,
        icon: Icons.system_update,
      );
    }
    if (status.isYanked) {
      return AppBadge(
        label: context.tr('plugins.status.yanked'),
        tone: AppBadgeTone.warning,
      );
    }
    if (status.isDeprecated) {
      return AppBadge(
        label: context.tr('plugins.status.deprecated'),
        tone: AppBadgeTone.warning,
      );
    }
    return null;
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
          ? (target
                ? context.tr('plugins.enabledToast')
                : context.tr('plugins.disabledToast'))
          : context.tr('plugins.notFound'),
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
        title: Text(
          context.tr(
            isCore ? 'plugins.removeCoreTitle' : 'plugins.removeTitle',
          ),
        ),
        content: Text(
          isCore
              ? context.tr('plugins.removeCoreBody')
              : context.tr(
                  'plugins.removeBody',
                  args: <String, Object?>{'name': plugin.manifest.name},
                ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('common.delete')),
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
      message: ok
          ? context.tr('plugins.removed')
          : context.tr('plugins.notFound'),
      tone: ok ? AppToastTone.success : AppToastTone.error,
    );
  }

  Future<void> _sideload(BuildContext context, WidgetRef ref) async {
    final service = ref.read(pluginSideloadProvider);
    try {
      final package = await service.pick(
        dialogTitle: context.tr('plugins.pickFileTitle'),
      );
      if (package == null || !context.mounted) {
        return;
      }
      final manifest = package.manifest;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('plugins.installTitle')),
          content: Text(
            context.tr(
              'plugins.installBody',
              args: <String, Object?>{
                'name': manifest.name,
                'version': manifest.version,
                'id': manifest.pluginId,
                'permissions': manifest.permissions
                    .map((permission) => permission.wireName)
                    .join(', '),
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
              child: Text(context.tr('common.install')),
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
        message: context.tr(
          'plugins.installed',
          args: <String, Object?>{'name': plugin.manifest.name},
        ),
        tone: AppToastTone.success,
      );
    } on AppError catch (error) {
      if (context.mounted) {
        showAppToast(
          context,
          message: context.trError(error),
          tone: AppToastTone.error,
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        showAppToast(
          context,
          message: context.tr(
            'plugins.installFailed',
            args: <String, Object?>{'error': context.trErrorObject(error)},
          ),
          tone: AppToastTone.error,
        );
      }
    }
  }
}
