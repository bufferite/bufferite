import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/engine/pipeline.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

final class _EchoRuntime implements SandboxRuntime {
  @override
  Future<Buffer> execute(
    Buffer input,
    Map<String, Object?> args,
    SandboxContext context,
  ) async {
    context.ensureActive();
    return TextBuffer('${context.pluginId}:${input.asText()}');
  }
}

void main() {
  group('SandboxConfig', () {
    test('default memiliki timeout, memori, dan cpu', () {
      final config = SandboxConfig.defaults;
      expect(config.stepTimeout, const Duration(seconds: 2));
      expect(config.memoryLimitBytes, 64 * 1024 * 1024);
      expect(config.permissions, <PluginPermission>{PluginPermission.cpu});
    });

    test('izin dan resource dapat dioverride, cpu selalu aktif', () {
      final config = SandboxConfig(
        stepTimeout: const Duration(milliseconds: 500),
        memoryLimitBytes: 8 * 1024 * 1024,
        permissions: <PluginPermission>{
          PluginPermission.net,
          PluginPermission.fileRead,
        },
      );

      expect(config.stepTimeout, const Duration(milliseconds: 500));
      expect(config.memoryLimitBytes, 8 * 1024 * 1024);
      expect(config.permissions, <PluginPermission>{
        PluginPermission.cpu,
        PluginPermission.net,
        PluginPermission.fileRead,
      });
    });

    test('config dan permissions immutable', () {
      final config = SandboxConfig.defaults;
      expect(
        () => config.permissions.add(PluginPermission.net),
        throwsUnsupportedError,
      );
    });

    test('copyWith mempertahankan nilai yang tidak diubah', () {
      final config = SandboxConfig.defaults.copyWith(
        stepTimeout: const Duration(seconds: 5),
      );
      expect(config.stepTimeout, const Duration(seconds: 5));
      expect(config.memoryLimitBytes, 64 * 1024 * 1024);
      expect(config.permissions, <PluginPermission>{PluginPermission.cpu});
    });

    test('menolak timeout dan memori tidak valid', () {
      expect(
        () => SandboxConfig(stepTimeout: Duration.zero),
        throwsArgumentError,
      );
      expect(
        () => SandboxConfig(stepTimeout: const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
      expect(() => SandboxConfig(memoryLimitBytes: 0), throwsArgumentError);
      expect(() => SandboxConfig(memoryLimitBytes: -1), throwsArgumentError);
    });
  });

  group('SandboxContext', () {
    test('menyediakan guard izin sesuai config', () {
      final context = SandboxContext(
        pluginId: 'com.test.pack',
        operationId: 'test.operation',
        stepId: 'step-1',
        config: SandboxConfig.defaults,
      );

      expect(context.permissionGuard.allows(PluginPermission.cpu), isTrue);
      expect(
        context.permissionGuard.allows(PluginPermission.fileRead),
        isFalse,
      );
      expect(
        () => context.requirePermission(PluginPermission.fileRead),
        throwsA(
          isA<AppError>()
              .having((error) => error.code, 'code', 'permission.denied')
              .having((error) => error.pluginId, 'pluginId', 'com.test.pack'),
        ),
      );
    });

    test('mendeteksi pembatalan', () {
      final token = CancellationToken();
      final context = SandboxContext(
        pluginId: 'com.test.pack',
        operationId: 'test.operation',
        config: SandboxConfig.defaults,
        cancellation: token,
      );

      expect(context.isCancelled, isFalse);
      context.ensureActive();
      token.cancel();
      expect(context.isCancelled, isTrue);
      expect(
        context.ensureActive,
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'operation.cancelled',
          ),
        ),
      );
    });

    test('menolak identitas kosong', () {
      expect(
        () => SandboxContext(
          pluginId: ' ',
          operationId: 'test.operation',
          config: SandboxConfig.defaults,
        ),
        throwsArgumentError,
      );
      expect(
        () => SandboxContext(
          pluginId: 'com.test.pack',
          operationId: '',
          config: SandboxConfig.defaults,
        ),
        throwsArgumentError,
      );
    });
  });

  group('SandboxRuntime', () {
    test('runtime menerima konteks eksekusi', () async {
      final context = SandboxContext(
        pluginId: 'com.test.pack',
        operationId: 'test.echo',
        config: SandboxConfig.defaults,
      );

      final output = await _EchoRuntime().execute(
        const TextBuffer('halo'),
        const <String, Object?>{},
        context,
      );

      expect(output, const TextBuffer('com.test.pack:halo'));
    });
  });
}
