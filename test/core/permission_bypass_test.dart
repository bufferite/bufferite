import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runtime contoh yang menghormati izin sebelum side effect.
final class _GuardedRuntime implements SandboxRuntime {
  const _GuardedRuntime({required this.permission});

  final PluginPermission permission;

  @override
  Future<Buffer> execute(
    Buffer input,
    Map<String, Object?> args,
    SandboxContext context,
  ) async {
    context.ensureActive();
    context.requirePermission(permission);
    return input;
  }
}

void main() {
  test('guard default hanya mengizinkan cpu', () {
    final guard = PermissionGuard(SandboxConfig.defaults.permissions);
    expect(guard.allows(PluginPermission.cpu), isTrue);
    for (final permission in <PluginPermission>[
      PluginPermission.net,
      PluginPermission.fileRead,
      PluginPermission.fileWrite,
    ]) {
      expect(guard.denialFor(permission), isA<AppError>());
    }
  });

  test('runtime tanpa izin gagal untuk net/fs', () async {
    final context = SandboxContext(
      pluginId: 'com.test.pack',
      operationId: 'test.op',
      config: SandboxConfig.defaults,
    );
    for (final permission in <PluginPermission>[
      PluginPermission.net,
      PluginPermission.fileRead,
      PluginPermission.fileWrite,
    ]) {
      expect(
        () => _GuardedRuntime(
          permission: permission,
        ).execute(const TextBuffer('x'), const <String, Object?>{}, context),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'permission.denied',
          ),
        ),
        reason: permission.wireName,
      );
    }
  });

  test('runtime dengan izin eksplisit berhasil', () async {
    final context = SandboxContext(
      pluginId: 'com.test.pack',
      operationId: 'test.op',
      config: SandboxConfig(
        permissions: const <PluginPermission>{PluginPermission.net},
      ),
    );
    final output = await const _GuardedRuntime(
      permission: PluginPermission.net,
    ).execute(const TextBuffer('ok'), const <String, Object?>{}, context);
    expect(output.asText(), 'ok');
  });
}
