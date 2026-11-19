import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/engine/pipeline.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:bufferite/core/runtime/wasm_lua_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

const String _dllRelative =
    r'build\wasm-spike\wasmtime-capi\target\release\wasmtime.dll';
const String _wasmRelative = r'build\lua-5.4.8-eh3.wasm';

String? _skipReason() {
  if (!Platform.isWindows) {
    return 'Spike wasmtime tersedia untuk Windows.';
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

SandboxContext _context({CancellationToken? cancellation}) {
  return SandboxContext(
    pluginId: 'com.example.lua',
    operationId: 'lua.transform',
    config: SandboxConfig.defaults,
    cancellation: cancellation,
  );
}

void main() {
  final skip = _skipReason();
  late Uint8List moduleBytes;

  setUpAll(() async {
    if (skip == null) {
      moduleBytes = await File(_wasmRelative).readAsBytes();
    }
  });

  Future<String> run(
    String source,
    String input, {
    Map<String, Object?> args = const <String, Object?>{},
    SandboxContext? context,
  }) async {
    final runtime = WasmLuaRuntime(
      source: source,
      moduleBytes: moduleBytes,
      libraryPath: _dllRelative,
    );
    final out = await runtime.execute(
      TextBuffer(input),
      args,
      context ?? _context(),
    );
    return out.asText();
  }

  test('transform mengembalikan string', () async {
    expect(
      await run(
        'function transform(input, args) return string.upper(input) end',
        'abc',
      ),
      'ABC',
    );
  }, skip: skip);

  test('output print ditangkap', () async {
    expect(
      await run(
        'function transform(input, args) print("x") print(input) end',
        'baris',
      ),
      'x\nbaris\n',
    );
  }, skip: skip);

  test('args tabel tersedia', () async {
    expect(
      await run(
        'function transform(input, args) return args.prefix .. input end',
        'dunia',
        args: <String, Object?>{'prefix': 'halo '},
      ),
      'halo dunia',
    );
  }, skip: skip);

  test('unicode dan karakter khusus utuh', () async {
    const input = 'baris1\n"kutip" ✓ 你好';
    expect(
      await run('function transform(input) return input end', input),
      input,
    );
  }, skip: skip);

  test('sandbox menghapus io dan os.execute', () async {
    expect(
      await run(
        'function transform() return tostring(io) .. "," .. '
            'tostring(os.execute) end',
        'x',
      ),
      'nil,nil',
    );
  }, skip: skip);

  test('sandbox menghapus package, require, debug, dan file loader', () async {
    expect(
      await run(
        'function transform() '
            'return tostring(package) .. "," .. tostring(require) .. "," .. '
            'tostring(debug) .. "," .. tostring(dofile) .. "," .. '
            'tostring(loadfile) .. "," .. tostring(os.getenv) .. "," .. '
            'tostring(os.tmpname) end',
        'x',
      ),
      'nil,nil,nil,nil,nil,nil,nil',
    );
  }, skip: skip);

  test('akses terlarang menghasilkan error terstruktur', () async {
    await expectLater(
      run(
        'function transform() '
            'local f = io.open("/etc/passwd", "r") return f:read("a") end',
        'x',
      ),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.lua_error',
        ),
      ),
    );
  }, skip: skip);

  test('transform tidak ada memberi error terstruktur', () async {
    await expectLater(
      run('x = 1', 'x'),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.lua_error',
        ),
      ),
    );
  }, skip: skip);

  test('syntax error memberi error terstruktur', () async {
    await expectLater(
      run('function transform( end', 'x'),
      throwsA(isA<AppError>()),
    );
  }, skip: skip);

  test('konteks dibatalkan menghentikan eksekusi', () async {
    final token = CancellationToken()..cancel();
    await expectLater(
      run(
        'function transform(input) return input end',
        'x',
        context: _context(cancellation: token),
      ),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'operation.cancelled',
        ),
      ),
    );
  }, skip: skip);

  test('timeout menghentikan loop tak berujung', () async {
    final runtime = WasmLuaRuntime(
      source: 'function transform() while true do end end',
      moduleBytes: moduleBytes,
      libraryPath: _dllRelative,
    );
    var ticks = 0;
    final ticker = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => ticks++,
    );
    try {
      await expectLater(
        runtime.execute(
          const TextBuffer('x'),
          const <String, Object?>{},
          SandboxContext(
            pluginId: 'com.example.lua',
            operationId: 'lua.transform',
            config: SandboxConfig(
              stepTimeout: const Duration(milliseconds: 300),
            ),
          ),
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'runtime.timeout',
          ),
        ),
      );
    } finally {
      ticker.cancel();
    }
    expect(ticks, greaterThan(0));
  }, skip: skip);

  test('pembatalan saat Lua berjalan menghentikan isolate', () async {
    final token = CancellationToken();
    final runtime = WasmLuaRuntime(
      source: 'function transform() while true do end end',
      moduleBytes: moduleBytes,
      libraryPath: _dllRelative,
    );
    final future = runtime.execute(
      const TextBuffer('x'),
      const <String, Object?>{},
      _context(cancellation: token),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    token.cancel();
    await expectLater(
      future,
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'operation.cancelled',
        ),
      ),
    );
  }, skip: skip);

  test('FileBuffer harus dimaterialisasi', () async {
    final runtime = WasmLuaRuntime(
      source: 'function transform(input) return input end',
      moduleBytes: moduleBytes,
      libraryPath: _dllRelative,
    );
    await expectLater(
      runtime.execute(
        const FileBuffer(path: '/tmp/a.txt', name: 'a.txt'),
        const <String, Object?>{},
        _context(),
      ),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.file_not_materialized',
        ),
      ),
    );
  }, skip: skip);

  test('worker dipakai ulang dan pulih setelah timeout', () async {
    final runtime = WasmLuaRuntime(
      source:
          'function transform(input) '
          'if input == "loop" then while true do end end '
          'return input end',
      moduleBytes: moduleBytes,
      libraryPath: _dllRelative,
    );

    final first = await runtime.execute(
      const TextBuffer('a'),
      const <String, Object?>{},
      _context(),
    );
    expect(first.asText(), 'a');

    await expectLater(
      runtime.execute(
        const TextBuffer('loop'),
        const <String, Object?>{},
        SandboxContext(
          pluginId: 'com.example.lua',
          operationId: 'lua.transform',
          config: SandboxConfig(stepTimeout: const Duration(milliseconds: 300)),
        ),
      ),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.timeout',
        ),
      ),
    );

    // Trap tidak boleh membuat store berikutnya langsung timeout (epoch naik).
    final second = await runtime.execute(
      const TextBuffer('b'),
      const <String, Object?>{},
      _context(),
    );
    expect(second.asText(), 'b');

    await runtime.dispose();
  }, skip: skip);

  test('runtime yang sudah dilepas menolak eksekusi', () async {
    final runtime = WasmLuaRuntime(
      source: 'function transform(input) return input end',
      moduleBytes: moduleBytes,
      libraryPath: _dllRelative,
    );
    await runtime.dispose();

    await expectLater(
      runtime.execute(
        const TextBuffer('x'),
        const <String, Object?>{},
        _context(),
      ),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.disposed',
        ),
      ),
    );
  }, skip: skip);
}
