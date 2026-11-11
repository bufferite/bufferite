import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PluginPermission', () {
    test('izin kosong berarti cpu saja', () {
      expect(PluginPermission.parseAll(null), <PluginPermission>{
        PluginPermission.cpu,
      });
    });

    test('menambahkan cpu otomatis dan menerima izin dikenal', () {
      final permissions = PluginPermission.parseAll(<Object?>[
        'net',
        'file:read',
        'file:write',
      ]);
      expect(permissions, <PluginPermission>{
        PluginPermission.cpu,
        PluginPermission.net,
        PluginPermission.fileRead,
        PluginPermission.fileWrite,
      });
    });

    test('menolak izin tidak dikenal', () {
      expect(
        () => PluginPermission.parseAll(<Object?>['camera']),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.permission_unknown',
          ),
        ),
      );
    });

    test('menolak permissions bukan array string', () {
      expect(
        () => PluginPermission.parseAll('cpu'),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.permissions_invalid',
          ),
        ),
      );
      expect(
        () => PluginPermission.parseAll(<Object?>[1]),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.permissions_invalid',
          ),
        ),
      );
    });
  });

  group('PermissionGuard', () {
    test('mengizinkan izin yang diberikan', () {
      final guard = PermissionGuard(<PluginPermission>{
        PluginPermission.cpu,
        PluginPermission.net,
      });
      expect(guard.allows(PluginPermission.cpu), isTrue);
      expect(guard.allows(PluginPermission.net), isTrue);
      expect(guard.allows(PluginPermission.fileRead), isFalse);
      expect(guard.denialFor(PluginPermission.net), isNull);
    });

    test('menghasilkan error permission.denied dengan konteks', () {
      final guard = PermissionGuard(const <PluginPermission>[
        PluginPermission.cpu,
      ]);
      final error = guard.denialFor(
        PluginPermission.fileWrite,
        pluginId: 'com.test.pack',
      );
      expect(error, isNotNull);
      expect(error!.category, ErrorCategory.permission);
      expect(error.code, 'permission.denied');
      expect(error.pluginId, 'com.test.pack');
      expect(error.details['permission'], 'file:write');
    });
  });
}
