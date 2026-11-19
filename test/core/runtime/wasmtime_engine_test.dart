import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/runtime/lua_program.dart';
import 'package:bufferite/core/runtime/wasmtime/wasmtime_engine.dart';
import 'package:bufferite/core/runtime/wasmtime/wasmtime_ffi.dart';
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

Future<Uint8List> _moduleBytes() async {
  return await File(_wasmRelative).readAsBytes();
}

void main() {
  final skip = _skipReason();

  test('layout struct FFI sesuai C API', () {
    expect(sizeOf<WasmByteVec>(), 16);
    expect(sizeOf<WasmtimeInstance>(), 16);
    expect(sizeOf<WasmtimeExtern>(), 32);
  });

  test('print(2+2) lewat WASI', () async {
    final engine = WasmtimeEngine(libraryPath: _dllRelative);
    final module = engine.compile(await _moduleBytes());
    try {
      final result = engine.run(module, <String>['lua', '-e', 'print(2+2)']);
      expect(result.isSuccess, isTrue, reason: result.failureMessage);
      expect(result.stdout.trim(), '4');
      expect(result.exitCode, 0);
    } finally {
      module.close();
      engine.close();
    }
  }, skip: skip);

  test('pcall menangkap error Lua', () async {
    final engine = WasmtimeEngine(libraryPath: _dllRelative);
    final module = engine.compile(await _moduleBytes());
    try {
      final result = engine.run(module, <String>[
        'lua',
        '-e',
        'local ok, err = pcall(function() error("boom") end); '
            'print(ok, err)',
      ]);
      expect(result.isSuccess, isTrue, reason: result.failureMessage);
      expect(result.stdout.trim(), startsWith('false'));
      expect(result.stdout, contains('boom'));
    } finally {
      module.close();
      engine.close();
    }
  }, skip: skip);

  test('script error menghasilkan exit code 1 dan stderr', () async {
    final engine = WasmtimeEngine(libraryPath: _dllRelative);
    final module = engine.compile(await _moduleBytes());
    try {
      final result = engine.run(module, <String>[
        'lua',
        '-e',
        'error("gagal")',
      ]);
      expect(result.isSuccess, isFalse);
      expect(result.exitCode, isNot(0));
      expect(result.failureMessage, contains('gagal'));
    } finally {
      module.close();
      engine.close();
    }
  }, skip: skip);

  test('argv besar (input teks) tetap utuh', () async {
    final engine = WasmtimeEngine(libraryPath: _dllRelative);
    final module = engine.compile(await _moduleBytes());
    final payload = 'baris ✓ 你好\n' * 2000;
    final script =
        'local s = ${luaStringLiteral(payload)}\nprint(#s)';
    try {
      final result = engine.run(module, <String>['lua', '-e', script]);
      expect(result.isSuccess, isTrue, reason: result.failureMessage);
      expect(result.stdout.trim(), utf8.encode(payload).length.toString());
    } finally {
      module.close();
      engine.close();
    }
  }, skip: skip);

  test('modul rusak memberi WasmtimeException', () async {
    final engine = WasmtimeEngine(libraryPath: _dllRelative);
    try {
      expect(
        () => engine.compile(Uint8List.fromList(<int>[0, 97, 115, 109])),
        throwsA(isA<WasmtimeException>()),
      );
    } finally {
      engine.close();
    }
  }, skip: skip);
}
