import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/runtime/dsl_runtime.dart';
import 'package:bufferite/core/runtime/lua_runtime.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:bufferite/core/runtime/wasm_lua_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

const String _dllRelative =
    r'build\wasm-spike\wasmtime-capi\target\release\wasmtime.dll';
const String _wasmRelative = r'build\lua-5.4.8-eh3.wasm';

String? _wasmSkipReason() {
  if (!Platform.isWindows) {
    return 'Engine WASM diuji di Windows.';
  }
  // ignore: avoid_slow_async_io
  if (!File(_dllRelative).existsSync()) {
    return 'wasmtime.dll belum dibangun (build/wasm-spike).';
  }
  // ignore: avoid_slow_async_io
  if (!File(_wasmRelative).existsSync()) {
    return 'lua_runtime.wasm belum dibangun (build/wasm-spike).';
  }
  return null;
}

SandboxContext _context({
  Set<PluginPermission> permissions = const <PluginPermission>{
    PluginPermission.cpu,
  },
  Duration timeout = const Duration(seconds: 10),
}) {
  return SandboxContext(
    pluginId: 'com.example.permission',
    operationId: 'permission.probe',
    stepId: 'step-1',
    config: SandboxConfig(stepTimeout: timeout, permissions: permissions),
  );
}

/// Probe yang harus gagal karena runtime tidak menyediakan host capability.
/// Semua dijalankan dengan izin maksimum agar terbukti bukan sekadar
/// penolakan daftar izin.
const Map<String, String> _luaProbes = <String, String>{
  'io.open':
      'function transform() return io.open("/etc/passwd", "r") end',
  'io.write': 'function transform() io.write("x") end',
  'os.execute': 'function transform() return os.execute("id") end',
  'os.getenv': 'function transform() return os.getenv("HOME") end',
  'os.remove': 'function transform() return os.remove("/tmp/x") end',
  'os.rename': 'function transform() return os.rename("a", "b") end',
  'os.setlocale': 'function transform() return os.setlocale("C") end',
  'os.tmpname': 'function transform() return os.tmpname() end',
  'dofile': 'function transform() return dofile("plugin.lua") end',
  'loadfile': 'function transform() return loadfile("plugin.lua") end',
  'require': 'function transform() return require("socket") end',
  'package': 'function transform() return package.path end',
  'debug': 'function transform() return debug.getinfo(1) end',
};

Future<AppError> _expectError(Future<Buffer> Function() run) async {
  try {
    await run();
  } on AppError catch (error) {
    return error;
  }
  fail('Probe seharusnya gagal, tetapi berhasil.');
}

Future<void> _assertLuaProbeBlocked(
  SandboxRuntime runtime,
  String probe,
) async {
  final allPermissions = <PluginPermission>{...PluginPermission.values};
  final error = await _expectError(
    () => runtime.execute(
      const TextBuffer('x'),
      const <String, Object?>{},
      _context(permissions: allPermissions),
    ),
  );
  expect(
    error.code,
    'runtime.lua_error',
    reason: 'Probe $probe harus diblokir runtime Lua.',
  );
  expect(error.pluginId, 'com.example.permission');
  expect(error.stepId, 'step-1');
}

void main() {
  final wasmSkip = _wasmSkipReason();
  late Uint8List moduleBytes;

  setUpAll(() async {
    if (wasmSkip == null) {
      moduleBytes = await File(_wasmRelative).readAsBytes();
    }
  });

  group('DSL tanpa akses host', () {
    test('op berbahaya tidak dikenal ditolak saat parse', () {
      for (final op in <String>['http_get', 'shell', 'read_file', 'write_file']) {
        expect(
          () => DslRuntime.parse(
            '{"version":1,"steps":[{"op":"$op","url":"https://example.com"}]}',
          ),
          throwsA(
            isA<AppError>().having(
              (error) => error.code,
              'code',
              'plugin.dsl_invalid',
            ),
          ),
          reason: op,
        );
      }
    });

    test('file buffer tidak dimaterialisasi walau izin file:read ada', () async {
      final runtime = DslRuntime.parse(
        '{"version":1,"steps":[{"op":"map","mapping":{"a":"b"}}]}',
      );
      final error = await _expectError(
        () => runtime.execute(
          const FileBuffer(path: '/tmp/a.txt', name: 'a.txt'),
          const <String, Object?>{},
          _context(
            permissions: <PluginPermission>{
              PluginPermission.fileRead,
              PluginPermission.fileWrite,
            },
          ),
        ),
      );
      expect(error.code, 'runtime.file_not_materialized');
    });
  });

  group('Lua native tanpa akses host', () {
    for (final entry in _luaProbes.entries) {
      test(entry.key, () async {
        await _assertLuaProbeBlocked(LuaRuntime(entry.value), entry.key);
      });
    }

    test('load hanya menerima chunk teks', () async {
      final runtime = LuaRuntime(
        'function transform() '
        'local f = load(string.dump(function() return 7 end)) '
        'return f == nil and "blocked" or "allowed" end',
      );
      final output = await runtime.execute(
        const TextBuffer('x'),
        const <String, Object?>{},
        _context(),
      );
      expect(output.asText(), 'blocked');
    });

    test('load teks tetap berfungsi', () async {
      final runtime = LuaRuntime(
        'function transform() return tostring(load("return 7")()) end',
      );
      final output = await runtime.execute(
        const TextBuffer('x'),
        const <String, Object?>{},
        _context(),
      );
      expect(output.asText(), '7');
    });
  });

  group('Lua WASM tanpa akses host', () {
    for (final entry in _luaProbes.entries) {
      test(entry.key, () async {
        final runtime = WasmLuaRuntime(
          source: entry.value,
          moduleBytes: moduleBytes,
          libraryPath: _dllRelative,
        );
        try {
          await _assertLuaProbeBlocked(runtime, entry.key);
        } finally {
          await runtime.dispose();
        }
      }, skip: wasmSkip);
    }

    test('load hanya menerima chunk teks', () async {
      final runtime = WasmLuaRuntime(
        source:
            'function transform() '
            'local f = load(string.dump(function() return 7 end)) '
            'return f == nil and "blocked" or "allowed" end',
        moduleBytes: moduleBytes,
        libraryPath: _dllRelative,
      );
      try {
        final output = await runtime.execute(
          const TextBuffer('x'),
          const <String, Object?>{},
          _context(),
        );
        expect(output.asText(), 'blocked');
      } finally {
        await runtime.dispose();
      }
    }, skip: wasmSkip);
  });

  test('izin yang tidak diberikan ditolak dengan pesan jelas', () {
    final context = _context();
    for (final permission in <PluginPermission>[
      PluginPermission.net,
      PluginPermission.fileRead,
      PluginPermission.fileWrite,
    ]) {
      final error = _expectErrorSync(() {
        context.requirePermission(permission);
      });
      expect(error.code, 'permission.denied');
      expect(error.message, contains(permission.wireName));
      expect(error.details['permission'], permission.wireName);
      expect(error.pluginId, 'com.example.permission');
    }
  });
}

AppError _expectErrorSync(void Function() run) {
  try {
    run();
  } on AppError catch (error) {
    return error;
  }
  fail('Pemanggilan seharusnya melempar AppError.');
}
