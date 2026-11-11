import '../error/app_error.dart';

/// Izin yang dikenal oleh manifest plugin dan runtime.
enum PluginPermission {
  cpu('cpu'),
  net('net'),
  fileRead('file:read'),
  fileWrite('file:write');

  const PluginPermission(this.wireName);

  final String wireName;

  static PluginPermission parse(String value) {
    for (final permission in values) {
      if (permission.wireName == value) {
        return permission;
      }
    }
    throw AppError(
      category: ErrorCategory.validation,
      code: 'plugin.permission_unknown',
      message: 'Izin plugin tidak dikenal: $value',
      details: <String, Object?>{'permission': value},
    );
  }

  /// Parse daftar izin manifest. `cpu` selalu ditambahkan karena merupakan
  /// izin dasar semua plugin.
  static Set<PluginPermission> parseAll(Object? value) {
    if (value == null) {
      return const <PluginPermission>{PluginPermission.cpu};
    }
    if (value is! List) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'plugin.permissions_invalid',
        message: 'Permissions plugin harus berupa array string.',
      );
    }

    final permissions = <PluginPermission>{PluginPermission.cpu};
    for (final item in value) {
      if (item is! String) {
        throw const AppError(
          category: ErrorCategory.validation,
          code: 'plugin.permissions_invalid',
          message: 'Setiap permission plugin harus berupa string.',
        );
      }
      permissions.add(parse(item));
    }
    return Set<PluginPermission>.unmodifiable(permissions);
  }
}

/// Pemeriksaan izin sebelum runtime melakukan side effect.
final class PermissionGuard {
  PermissionGuard(Iterable<PluginPermission> granted)
    : granted = Set<PluginPermission>.unmodifiable(granted);

  final Set<PluginPermission> granted;

  bool allows(PluginPermission permission) => granted.contains(permission);

  AppError? denialFor(PluginPermission permission, {String? pluginId}) {
    if (allows(permission)) {
      return null;
    }
    return AppError(
      category: ErrorCategory.permission,
      code: 'permission.denied',
      message: 'Plugin tidak memiliki izin ${permission.wireName}.',
      pluginId: pluginId,
      details: <String, Object?>{'permission': permission.wireName},
    );
  }
}
