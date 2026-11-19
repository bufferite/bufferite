import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/runtime/dsl_runtime.dart';
import 'package:bufferite/core/runtime/lua_runtime.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:bufferite/core/runtime/wasm_lua_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

const String _dllRelative =
    r'build\wasm-spike\wasmtime-capi\target\release\wasmtime.dll';
const String _wasmRelative = r'build\lua-5.4.8-eh3.wasm';

String? _skipReason() {
  if (!Platform.isWindows) {
    return 'Kontrak lintas engine dijalankan di Windows.';
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

SandboxContext _context() {
  return SandboxContext(
    pluginId: 'com.example.contract',
    operationId: 'contract.transform',
    config: SandboxConfig(stepTimeout: const Duration(seconds: 10)),
  );
}

/// Kasus yang harus berperilaku sama di `lua_dart` dan Lua WASM.
const Map<String, String> _cases = <String, String>{
  'upper': 'function transform(input) return string.upper(input) end',
  'pass_through': 'function transform(input) return input end',
  'print_only': 'function transform() print("a") print(2) end',
  'args': 'function transform(input, args) return args.prefix .. input end',
  'unicode': 'function transform(input) return "✓ " .. input end',
  'sandbox': 'function transform() return tostring(io) end',
  'missing_transform': 'local x = 1',
  'pcall': 'function transform() local ok = pcall(error, "x") '
      'return tostring(ok) end',
  'table_return': 'function transform() return {1, 2} end',
  'gsub': 'function transform(input) return (input:gsub("a", "b")) end',
};

const List<String> _inputs = <String>['abc', 'baris1\nkutip "x"', '你好'];

Future<String?> _run(
  Future<Buffer> Function() execute,
) async {
  try {
    return (await execute()).asText();
  } on Object {
    return null;
  }
}

void main() {
  final skip = _skipReason();
  late Uint8List moduleBytes;

  setUpAll(() async {
    if (skip == null) {
      moduleBytes = await File(_wasmRelative).readAsBytes();
    }
  });

  group('kontrak lua_dart == Lua WASM', () {
    for (final entry in _cases.entries) {
      test(entry.key, () async {
        final dartRuntime = LuaRuntime(entry.value);
        final wasmRuntime = WasmLuaRuntime(
          source: entry.value,
          moduleBytes: moduleBytes,
          libraryPath: _dllRelative,
        );
        try {
          for (final input in _inputs) {
            final args = <String, Object?>{'prefix': 'halo '};

            final expected = await _run(
              () => dartRuntime.execute(TextBuffer(input), args, _context()),
            );
            final actual = await _run(
              () => wasmRuntime.execute(TextBuffer(input), args, _context()),
            );

            expect(
              actual,
              expected,
              reason: 'Kasus ${entry.key} berbeda untuk input "$input"',
            );
          }
        } finally {
          await wasmRuntime.dispose();
        }
      }, skip: skip);
    }
  });

  group('kontrak DSL == Lua native == Lua WASM', () {
    for (final entry in _dslCases) {
      test(entry.name, () async {
        final dsl = DslRuntime.parse(entry.dsl);
        final native = LuaRuntime(entry.lua);
        final wasm = WasmLuaRuntime(
          source: entry.lua,
          moduleBytes: moduleBytes,
          libraryPath: _dllRelative,
        );
        try {
          final expected = (await dsl.execute(
            TextBuffer(entry.input),
            const <String, Object?>{},
            _context(),
          )).asText();
          final nativeOutput = (await native.execute(
            TextBuffer(entry.input),
            const <String, Object?>{},
            _context(),
          )).asText();
          final wasmOutput = (await wasm.execute(
            TextBuffer(entry.input),
            const <String, Object?>{},
            _context(),
          )).asText();

          expect(nativeOutput, expected, reason: 'Lua native ≠ DSL');
          expect(wasmOutput, expected, reason: 'Lua WASM ≠ DSL');
        } finally {
          await wasm.dispose();
        }
      }, skip: skip);
    }
  });
}

typedef _DslContractCase = ({
  String name,
  String dsl,
  String lua,
  String input,
});

final List<_DslContractCase> _dslCases = <_DslContractCase>[
  (
    name: 'map',
    dsl: '{"version":1,"steps":[{"op":"map","mapping":{"a":"o"}}]}',
    lua: 'function transform(input) return (input:gsub("a", "o")) end',
    input: 'banana',
  ),
  (
    name: 'map_first_only',
    dsl:
        '{"version":1,"steps":[{"op":"map","mapping":{"a":"o"},"all":false}]}',
    lua: 'function transform(input) return (input:gsub("a", "o", 1)) end',
    input: 'banana',
  ),
  (
    name: 'regex_replace',
    dsl:
        '{"version":1,"steps":[{"op":"regex_replace",'
        '"pattern":"\\\\s+","replacement":" "}]}',
    lua: 'function transform(input) return (input:gsub("%s+", " ")) end',
    input: 'a   b\nc',
  ),
  (
    name: 'regex_ignore_case',
    dsl:
        '{"version":1,"steps":[{"op":"regex_replace","pattern":"abc",'
        '"replacement":"x","ignore_case":true}]}',
    lua:
        'function transform(input) '
        'return (input:gsub("[Aa][Bb][Cc]", "x")) end',
    input: 'ABC abc',
  ),
  (
    name: 'rename_json',
    dsl:
        '{"version":1,"steps":[{"op":"rename","mapping":{"old":"new"}}]}',
    lua:
        'function transform(input) '
        'return (input:gsub("\\"old\\"", "\\"new\\"")) end',
    input: '{"old":1,"keep":2}',
  ),
];
