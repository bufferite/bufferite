import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../plugin/plugin_permission.dart';
import '../design_tokens.dart';

/// Dialog izin plugin sesuai `DESIGN.md` §6.6.
///
/// Tidak bisa ditutup dengan tap luar; pengguna wajib memilih aksi.
Future<bool> showPermissionDialog(
  BuildContext context, {
  required String pluginName,
  required Set<PluginPermission> permissions,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        PermissionDialog(pluginName: pluginName, permissions: permissions),
  );
  return result ?? false;
}

class PermissionDialog extends StatelessWidget {
  const PermissionDialog({
    super.key,
    required this.pluginName,
    required this.permissions,
  });

  final String pluginName;
  final Set<PluginPermission> permissions;

  bool get _hasNetwork => permissions.contains(PluginPermission.net);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;

    return AlertDialog(
      title: Text(
        context.tr(
          _hasNetwork ? 'permissions.networkTitle' : 'permissions.title',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.tr('permissions.body', args: <String, Object?>{
              'name': pluginName,
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final permission in permissions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    _icon(permission),
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(_description(context, permission))),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr('permissions.warning'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: _hasNetwork
              ? FilledButton.styleFrom(backgroundColor: palette.danger)
              : null,
          child: Text(context.tr('permissions.approve')),
        ),
      ],
    );
  }

  IconData _icon(PluginPermission permission) {
    return switch (permission) {
      PluginPermission.cpu => Icons.memory,
      PluginPermission.net => Icons.language,
      PluginPermission.fileRead => Icons.download,
      PluginPermission.fileWrite => Icons.upload,
    };
  }

  String _description(BuildContext context, PluginPermission permission) {
    return switch (permission) {
      PluginPermission.cpu => context.tr('permissions.cpu'),
      PluginPermission.net => context.tr('permissions.net'),
      PluginPermission.fileRead => context.tr('permissions.fileRead'),
      PluginPermission.fileWrite => context.tr('permissions.fileWrite'),
    };
  }
}
