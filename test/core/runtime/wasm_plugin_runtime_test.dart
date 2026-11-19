import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/runtime/plugin_runtime.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:bufferite/core/runtime/wasm_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/plugin_fixtures.dart';

const String _dllRelative =
    r'build\wasm-spike\wasmtime-capi\target\release\wasmtime.dll';
const String _fixtures = r'test\fixtures\wasm';

String? _skipReason() {
  if (!Platform.isWindows) {
    return 'Tier WASM diuji dengan wasmtime Windows.';
  }
  // ignore: avoid_slow_async_io
  if (!File(_dllRelative).existsSync()) {
    return 'wasmtime.dll belum dibangun (build/wasm-spike).';
  }
  return null;
}

Uint8List _fixture(String name) {
  return File('$_fixtures\\$name.wasm').readAsBytesSync();
}

SandboxContext _context({
  String operationId = 'plugin.echo',
  Duration timeout = const Duration(seconds: 10),
  int memoryLimitBytes = 64 * 1024 * 1024,
  Set<PluginPermission> permissions = const <PluginPermission>{
    PluginPermission.cpu,
  },
}) {
  return SandboxContext(
    pluginId: 'com.example.wasmplugin',
    operationId: operationId,
    stepId: 'step-wasm',
    config: SandboxConfig(
      stepTimeout: timeout,
      memoryLimitBytes: memoryLimitBytes,
      permissions: permissions,
    ),
  );
}

Future<AppError> _expectError(Future<Buffer> Function() run) async {
  try {
    await run();
  } on AppError catch (error) {
    return error;
  }
  fail('Eksekusi seharusnya gagal.');
}

void main() {
  final skip = _skipReason();

  test('modul WASI membaca stdin dan menulis stdout', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('echo_upper'),
      libraryPath: _dllRelative,
    );
    try {
      final output = await runtime.execute(
        const TextBuffer('halo 123'),
        const <String, Object?>{},
        _context(),
      );
      expect(output.asText(), 'HALO 123');
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test('argv berisi id operasi dan args JSON', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('argv_probe'),
      libraryPath: _dllRelative,
    );
    try {
      final output = await runtime.execute(
        const TextBuffer('abaikan'),
        const <String, Object?>{'prefix': 'x'},
        _context(operationId: 'plugin.args'),
      );
      expect(output.asText(), '3|plugin.args|{"prefix":"x"}');
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test('worker dipakai ulang untuk eksekusi berikutnya', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('echo_upper'),
      libraryPath: _dllRelative,
    );
    try {
      final first = await runtime.execute(
        const TextBuffer('satu'),
        const <String, Object?>{},
        _context(),
      );
      final second = await runtime.execute(
        const TextBuffer('dua'),
        const <String, Object?>{},
        _context(),
      );
      expect(first.asText(), 'SATU');
      expect(second.asText(), 'DUA');
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test('exit non-zero menjadi runtime.wasm_error dengan stderr', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('exit_error'),
      libraryPath: _dllRelative,
    );
    try {
      final error = await _expectError(
        () => runtime.execute(
          const TextBuffer('x'),
          const <String, Object?>{},
          _context(),
        ),
      );
      expect(error.code, 'runtime.wasm_error');
      expect(error.message, contains('boom dari plugin'));
      expect(error.pluginId, 'com.example.wasmplugin');
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test('akses file host diblokir walau izin file:read diberikan', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('fs_probe'),
      libraryPath: _dllRelative,
    );
    try {
      final output = await runtime.execute(
        const TextBuffer('x'),
        const <String, Object?>{},
        _context(
          permissions: <PluginPermission>{
            PluginPermission.fileRead,
            PluginPermission.fileWrite,
            PluginPermission.net,
          },
        ),
      );
      expect(output.asText(), 'blocked');
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test('import host function tidak dikenal ditolak', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('host_import'),
      libraryPath: _dllRelative,
    );
    try {
      final error = await _expectError(
        () => runtime.execute(
          const TextBuffer('x'),
          const <String, Object?>{},
          _context(),
        ),
      );
      expect(error.code, 'runtime.wasm_error');
      expect(error.message.toLowerCase(), contains('import'));
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test('timeout menghentikan loop dan worker tetap hidup', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('spin_if'),
      libraryPath: _dllRelative,
    );
    try {
      final error = await _expectError(
        () => runtime.execute(
          const TextBuffer('x'),
          const <String, Object?>{},
          _context(
            operationId: 'spin',
            timeout: const Duration(milliseconds: 300),
          ),
        ),
      );
      expect(error.code, 'runtime.timeout');

      final output = await runtime.execute(
        const TextBuffer('pulih'),
        const <String, Object?>{},
        _context(operationId: 'echo'),
      );
      expect(output.asText(), 'pulih');
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test('timeout berulang tidak mematikan worker', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('spin_if'),
      libraryPath: _dllRelative,
    );
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final error = await _expectError(
          () => runtime.execute(
            const TextBuffer('x'),
            const <String, Object?>{},
            _context(
              operationId: 'spin',
              timeout: const Duration(milliseconds: 250),
            ),
          ),
        );
        expect(error.code, 'runtime.timeout');
      }

      final output = await runtime.execute(
        const TextBuffer('lagi'),
        const <String, Object?>{},
        _context(operationId: 'echo'),
      );
      expect(output.asText(), 'lagi');
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test('eksekusi paralel diserialisasi dan tidak saling merusak', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('spin_if'),
      libraryPath: _dllRelative,
    );
    try {
      final spin = _expectError(
        () => runtime.execute(
          const TextBuffer('x'),
          const <String, Object?>{},
          _context(
            operationId: 'spin',
            timeout: const Duration(milliseconds: 250),
          ),
        ),
      );
      final echo = runtime.execute(
        const TextBuffer('paralel'),
        const <String, Object?>{},
        _context(operationId: 'echo'),
      );

      expect((await spin).code, 'runtime.timeout');
      expect((await echo).asText(), 'paralel');
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test('stdout melebihi batas memori ditolak dan worker pulih', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('stdout_flood'),
      libraryPath: _dllRelative,
    );
    try {
      final error = await _expectError(
        () => runtime.execute(
          const TextBuffer('x'),
          const <String, Object?>{},
          _context(memoryLimitBytes: 256 * 1024),
        ),
      );
      expect(error.code, 'runtime.wasm_error');
      expect(error.message, contains('stdout'));

      final output = await runtime.execute(
        const TextBuffer('x'),
        const <String, Object?>{},
        _context(memoryLimitBytes: 2 * 1024 * 1024),
      );
      expect(output.asText().length, 32 * 1024 * 16);
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test('FileBuffer harus dimaterialisasi', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('echo_upper'),
      libraryPath: _dllRelative,
    );
    try {
      final error = await _expectError(
        () => runtime.execute(
          const FileBuffer(path: '/tmp/a.txt', name: 'a.txt'),
          const <String, Object?>{},
          _context(),
        ),
      );
      expect(error.code, 'runtime.file_not_materialized');
    } finally {
      await runtime.dispose();
    }
  }, skip: skip);

  test(
    'loader menghasilkan executor tier wasm dari entrypoint .wasm',
    () async {
      final manifest = PluginManifest.fromJson(
        validManifestJson(tier: 'wasm', entrypoint: 'main.wasm'),
      );
      final plugin = InstalledPlugin(
        manifest: manifest,
        source: PluginSource.sideload,
        installedAt: DateTime.utc(2026, 1, 1),
        installPath: '/plugins/com.test.pack/1.0.0',
      );
      final loader = PluginRuntimeLoader(
        sandboxConfig: () => SandboxConfig.defaults,
        wasmtimeLibraryPath: _dllRelative,
        readEntrypoint: (_) async => _fixture('echo_upper'),
      );
      try {
        final operation = loader.operationFor(
          plugin,
          plugin.manifest.operations.single,
        );
        expect(operation, isNotNull);
        final output = await operation!.execute(
          const TextBuffer('loader'),
          const <String, Object?>{},
        );
        expect(output.asText(), 'LOADER');
      } finally {
        await loader.dispose();
      }
    },
    skip: skip,
  );

  test('runtime yang sudah dilepas menolak eksekusi', () async {
    final runtime = WasmPluginRuntime(
      moduleBytes: _fixture('echo_upper'),
      libraryPath: _dllRelative,
    );
    await runtime.dispose();

    final error = await _expectError(
      () => runtime.execute(
        const TextBuffer('x'),
        const <String, Object?>{},
        _context(),
      ),
    );
    expect(error.code, 'runtime.disposed');
  }, skip: skip);
}
