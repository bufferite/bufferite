import 'package:flutter/material.dart';

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
        _hasNetwork ? 'Plugin meminta akses internet' : 'Plugin meminta izin',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$pluginName meminta izin berikut:'),
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
                  Expanded(child: Text(_description(permission))),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Hanya setujui bila kamu memercayai plugin ini.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: _hasNetwork
              ? FilledButton.styleFrom(backgroundColor: palette.danger)
              : null,
          child: const Text('Setujui'),
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

  String _description(PluginPermission permission) {
    return switch (permission) {
      PluginPermission.cpu => 'cpu — memproses data di perangkat',
      PluginPermission.net => 'net — mengakses internet',
      PluginPermission.fileRead => 'file:read — membaca file',
      PluginPermission.fileWrite => 'file:write — menulis file',
    };
  }
}
