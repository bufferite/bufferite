import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_error.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/localized_error.dart';
import '../../../core/plugin/installed_plugin.dart';
import '../../../core/plugin/plugin_permission.dart';
import '../../../core/registry/registry_client.dart';
import '../../../core/registry/registry_index.dart';
import '../../../core/ui/components/app_badge.dart';
import '../../../core/ui/components/app_toast.dart';
import '../../../core/ui/components/permission_dialog.dart';
import '../../../core/ui/design_tokens.dart';
import '../plugin_providers.dart';
import 'registry_consent.dart';
import 'registry_error_text.dart';
import 'registry_providers.dart';

/// Detail satu rilis registry: metadata, izin, verifikasi, dan instalasi.
class RegistryDetailScreen extends ConsumerStatefulWidget {
  const RegistryDetailScreen({
    super.key,
    required this.entry,
    required this.snapshot,
  });

  final RegistryEntry entry;
  final RegistrySnapshot snapshot;

  @override
  ConsumerState<RegistryDetailScreen> createState() =>
      _RegistryDetailScreenState();
}

class _RegistryDetailScreenState extends ConsumerState<RegistryDetailScreen> {
  bool _installing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final appVersion = ref.watch(appVersionProvider);
    final installed = _installedPlugin(
      ref.watch(installedPluginsProvider).asData?.value ??
          const <InstalledPlugin>[],
    );
    final compatible = appVersion.isAtLeast(entry.minAppVersion);
    final selectable =
        entry.status == RegistryEntryStatus.active ||
        entry.status == RegistryEntryStatus.deprecated;
    final sameVersion = installed != null && installed.version == entry.version;
    final newerInstalled =
        installed != null && installed.version.compareTo(entry.version) > 0;
    final canInstall =
        compatible && selectable && !sameVersion && !newerInstalled;

    return Scaffold(
      appBar: AppBar(title: Text(entry.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              AppBadge(label: entry.tier.name),
              _statusBadge(entry.status),
              AppBadge(
                label: context.tr('registry.verifiedBadge'),
                tone: AppBadgeTone.success,
                icon: Icons.verified_outlined,
              ),
              if (installed != null)
                AppBadge(
                  label: context.tr(
                    'registry.installedVersion',
                    args: <String, Object?>{'version': installed.version},
                  ),
                  tone: AppBadgeTone.accent,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(entry.summary, style: theme.textTheme.bodyLarge),
          if (entry.description != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(entry.description!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.lg),
          _section(theme, context.tr('registry.detail.metadata')),
          _kv(context.tr('registry.detail.id'), entry.pluginId),
          _kv(context.tr('registry.detail.version'), entry.version.toString()),
          _kv(
            context.tr('registry.detail.minApp'),
            entry.minAppVersion.toString(),
          ),
          _kv(
            context.tr('registry.detail.size'),
            context.trPlural('common.bytes', entry.sizeBytes),
          ),
          _kv(
            context.tr('registry.detail.registry'),
            widget.snapshot.sourceUrl.toString(),
          ),
          if (entry.author != null)
            _kv(context.tr('registry.detail.author'), entry.author!),
          if (entry.license != null)
            _kv(context.tr('registry.detail.license'), entry.license!),
          if (entry.homepage != null)
            _kv(context.tr('registry.detail.homepage'), entry.homepage!),
          _kv(
            context.tr('registry.detail.published'),
            _dateLabel(entry.publishedAt.toLocal()),
          ),
          if (entry.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final tag in entry.tags) AppBadge(label: tag),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _section(theme, context.tr('registry.detail.permissions')),
          for (final permission in _sortedPermissions(entry.permissions))
            _kv(
              permission.wireName,
              _permissionDescription(context, permission),
            ),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, context.tr('registry.detail.verification')),
          Text(context.tr('registry.detail.indexSignature')),
          const SizedBox(height: AppSpacing.xs),
          Text(context.tr('registry.detail.packageSignature')),
          const SizedBox(height: AppSpacing.sm),
          _kv('SHA-256', entry.sha256),
          if (!compatible) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr(
                'registry.detail.incompatible',
                args: <String, Object?>{'version': entry.minAppVersion},
              ),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (!selectable) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr('registry.detail.unavailable'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (newerInstalled) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr(
                'registry.detail.newerInstalled',
                args: <String, Object?>{'version': installed.version},
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _installing || !canInstall ? null : _install,
            icon: _installing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    installed == null ? Icons.download : Icons.system_update,
                  ),
            label: Text(
              _installing
                  ? context.tr('registry.detail.installing')
                  : sameVersion
                  ? context.tr('registry.detail.installed')
                  : installed == null
                  ? context.tr('registry.detail.install')
                  : context.tr('registry.detail.update'),
            ),
          ),
        ],
      ),
    );
  }

  AppBadge _statusBadge(RegistryEntryStatus status) {
    return switch (status) {
      RegistryEntryStatus.active => AppBadge(
        label: context.tr('registry.status.active'),
        tone: AppBadgeTone.success,
      ),
      RegistryEntryStatus.deprecated => AppBadge(
        label: context.tr('registry.status.deprecated'),
        tone: AppBadgeTone.warning,
      ),
      RegistryEntryStatus.yanked => AppBadge(
        label: context.tr('registry.status.yanked'),
        tone: AppBadgeTone.warning,
      ),
      RegistryEntryStatus.revoked => AppBadge(
        label: context.tr('registry.status.revoked'),
        tone: AppBadgeTone.danger,
      ),
    };
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
            width: 120,
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

  List<PluginPermission> _sortedPermissions(Set<PluginPermission> permissions) {
    return permissions.toList()
      ..sort((a, b) => a.wireName.compareTo(b.wireName));
  }

  String _permissionDescription(
    BuildContext context,
    PluginPermission permission,
  ) {
    return switch (permission) {
      PluginPermission.cpu => context.tr('permissions.cpu'),
      PluginPermission.net => context.tr('permissions.net'),
      PluginPermission.fileRead => context.tr('permissions.fileRead'),
      PluginPermission.fileWrite => context.tr('permissions.fileWrite'),
    };
  }

  InstalledPlugin? _installedPlugin(List<InstalledPlugin> plugins) {
    for (final plugin in plugins) {
      if (plugin.pluginId == widget.entry.pluginId) {
        return plugin;
      }
    }
    return null;
  }

  Future<void> _install() async {
    if (!await ensureRegistryConsent(context, ref) || !mounted) {
      return;
    }
    final installed = _installedPlugin(
      ref.read(installedPluginsProvider).asData?.value ??
          const <InstalledPlugin>[],
    );
    final entry = widget.entry;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr(
            installed == null
                ? 'registry.detail.installTitle'
                : 'registry.detail.updateTitle',
          ),
        ),
        content: Text(
          installed == null
              ? context.tr(
                  'registry.detail.installBody',
                  args: <String, Object?>{
                    'name': entry.name,
                    'version': entry.version,
                    'id': entry.pluginId,
                    'size': context.trPlural('common.bytes', entry.sizeBytes),
                    'source': widget.snapshot.sourceUrl.host,
                    'permissions': entry.permissions
                        .map((permission) => permission.wireName)
                        .join(', '),
                  },
                )
              : context.tr(
                  'registry.detail.updateBody',
                  args: <String, Object?>{
                    'name': entry.name,
                    'installed': installed.version,
                    'version': entry.version,
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
    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    final requested = entry.permissions
        .where((permission) => permission != PluginPermission.cpu)
        .toSet();
    if (requested.isNotEmpty) {
      final granted = await showPermissionDialog(
        context,
        pluginName: entry.name,
        permissions: requested,
      );
      if (!granted || !mounted) {
        return;
      }
    }

    setState(() => _installing = true);
    try {
      final plugin = await ref
          .read(registryInstallServiceProvider)
          .install(entry: entry, snapshot: widget.snapshot);
      if (mounted) {
        showAppToast(
          context,
          message: context.tr(
            'registry.detail.installSuccess',
            args: <String, Object?>{'name': plugin.manifest.name},
          ),
          tone: AppToastTone.success,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        final message = error is AppError
            ? context.trError(error)
            : registryErrorText(context, error);
        showAppToast(
          context,
          message: context.tr(
            'registry.detail.installFailed',
            args: <String, Object?>{'error': message},
          ),
          tone: AppToastTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _installing = false);
      }
    }
  }

  String _dateLabel(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }
}
