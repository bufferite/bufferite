import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/plugin_integrity.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/core/runtime/plugin_runtime.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/plugin_fixtures.dart';

InstalledPlugin _plugin({
  String tier = 'lua',
  String entrypoint = 'main.lua',
  String? sha256,
  String? installPath = '/plugins/com.test.pack/1.0.0',
}) {
  final json = validManifestJson(tier: tier, entrypoint: entrypoint);
  if (sha256 != null) {
    json['integrity'] = <String, Object?>{'sha256': sha256};
  }
  return InstalledPlugin(
    manifest: PluginManifest.fromJson(json),
    source: PluginSource.sideload,
    installedAt: DateTime.utc(2026, 1, 1),
    installPath: installPath,
  );
}

PluginRuntimeLoader _loader({
  String? source,
  PluginEntrypointReader? reader,
  LuaEngine engine = LuaEngine.native,
  SandboxConfig? config,
}) {
  return PluginRuntimeLoader(
    sandboxConfig: () => config ?? SandboxConfig.defaults,
    luaEngine: engine,
    readEntrypoint:
        reader ??
        (path) async => Uint8List.fromList(utf8.encode(source ?? '')),
  );
}

Future<Buffer> _execute(Operation operation, String input) {
  return operation.execute(TextBuffer(input), const <String, Object?>{});
}

void main() {
  test('tier lua memakai source plugin dan menjalankan transform', () async {
    final plugin = _plugin();
    final operation = _loader(
      source: 'function transform(input) return string.upper(input) end',
    ).operationFor(plugin, plugin.manifest.operations.single);

    expect(operation, isNotNull);
    expect(operation!.id, 'test.operation');
    expect((await _execute(operation, 'abc')).asText(), 'ABC');
  });

  test('entrypoint hanya dibaca sekali untuk eksekusi berulang', () async {
    final plugin = _plugin();
    var reads = 0;
    final operation = _loader(
      reader: (path) async {
        reads++;
        expect(path, '/plugins/com.test.pack/1.0.0/main.lua');
        return Uint8List.fromList(
          utf8.encode('function transform(input) return input end'),
        );
      },
    ).operationFor(plugin, plugin.manifest.operations.single)!;

    await _execute(operation, 'a');
    await _execute(operation, 'b');

    expect(reads, 1);
  });

  test('evictPlugin memuat ulang entrypoint setelah runtime dilepas',
      () async {
    final plugin = _plugin();
    var reads = 0;
    final loader = _loader(
      reader: (path) async {
        reads++;
        return Uint8List.fromList(
          utf8.encode('function transform(input) return input end'),
        );
      },
    );
    final operation = loader.operationFor(
      plugin,
      plugin.manifest.operations.single,
    )!;

    await _execute(operation, 'a');
    await loader.evictPlugin(plugin.manifest.pluginId);
    await _execute(operation, 'b');

    expect(reads, 2);
  });

  test('tier dsl memakai DslRuntime', () async {
    final plugin = _plugin(tier: 'dsl', entrypoint: 'transform.json');
    final operation = _loader(
      source: '{"version": 1, "steps": ['
          '{"op": "map", "mapping": {"foo": "bar"}}]}',
    ).operationFor(plugin, plugin.manifest.operations.single)!;

    expect((await _execute(operation, 'foo-foo')).asText(), 'bar-bar');
  });

  test('hash entrypoint tidak cocok menolak eksekusi', () async {
    final plugin = _plugin(sha256: 'a' * 64);
    final operation = _loader(
      source: 'function transform(input) return input end',
    ).operationFor(plugin, plugin.manifest.operations.single)!;

    await expectLater(
      _execute(operation, 'x'),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'plugin.verify_failed',
        ),
      ),
    );
  });

  test('hash entrypoint cocok diloloskan', () async {
    const source = 'function transform(input) return input end';
    final plugin = _plugin(sha256: PluginIntegrity.sha256Hex(utf8.encode(source)));
    final operation = _loader(
      source: source,
    ).operationFor(plugin, plugin.manifest.operations.single)!;

    expect((await _execute(operation, 'ok')).asText(), 'ok');
  });

  test('entrypoint hilang menjadi plugin.entrypoint_missing', () async {
    final plugin = _plugin();
    final operation = _loader(
      reader: (path) async => throw FileSystemException('hilang', path),
    ).operationFor(plugin, plugin.manifest.operations.single)!;

    await expectLater(
      _execute(operation, 'x'),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'plugin.entrypoint_missing',
        ),
      ),
    );
  });

  test('engine WASM tanpa modul dilaporkan tidak tersedia', () async {
    final plugin = _plugin();
    final operation = _loader(
      source: 'function transform(input) return input end',
      engine: LuaEngine.wasm,
    ).operationFor(plugin, plugin.manifest.operations.single)!;

    await expectLater(
      _execute(operation, 'x'),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.wasm_unavailable',
        ),
      ),
    );
  });

  test('tier wasm menghasilkan executor ABI WASI', () {
    final plugin = _plugin(tier: 'wasm', entrypoint: 'main.wasm');

    final executor = _loader(source: '').operationFor(
      plugin,
      plugin.manifest.operations.single,
    );
    expect(executor, isNotNull);
    expect(executor!.id, 'test.operation');
  });

  test('plugin tanpa installPath belum punya executor', () {
    final plugin = _plugin(installPath: null);

    expect(
      _loader(source: '').operationFor(
        plugin,
        plugin.manifest.operations.single,
      ),
      isNull,
    );
  });
}
