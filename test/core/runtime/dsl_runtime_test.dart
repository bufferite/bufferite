import 'dart:convert';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/engine/pipeline.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/runtime/dsl_runtime.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

String _program(String steps) => '{"version": 1, "steps": [$steps]}';

SandboxContext _context({CancellationToken? cancellation}) {
  return SandboxContext(
    pluginId: 'com.example.dsl',
    operationId: 'dsl.transform',
    config: SandboxConfig.defaults,
    cancellation: cancellation,
  );
}

Future<String> _run(
  String source,
  String input, {
  SandboxContext? context,
}) async {
  final runtime = DslRuntime.parse(source);
  final buffer = await runtime.execute(
    TextBuffer(input),
    const <String, Object?>{},
    context ?? _context(),
  );
  return buffer.asText();
}

void main() {
  group('transformasi', () {
    test('map mengganti semua kemunculan', () async {
      final output = await _run(
        _program('{"op": "map", "mapping": {"foo": "bar"}}'),
        'foo-foo',
      );
      expect(output, 'bar-bar');
    });

    test('map all=false hanya mengganti kemunculan pertama', () async {
      final output = await _run(
        _program('{"op": "map", "mapping": {"foo": "bar"}, "all": false}'),
        'foo-foo',
      );
      expect(output, 'bar-foo');
    });

    test('regex_replace ignore case', () async {
      final source = _program(
        '{"op": "regex_replace", "pattern": "a.c", '
        '"replacement": "X", "ignore_case": true}',
      );
      expect(await _run(source, 'ABC abc'), 'X X');
    });

    test('regex_replace all=false hanya kecocokan pertama', () async {
      final source = _program(
        '{"op": "regex_replace", "pattern": "\\\\d", '
        '"replacement": "#", "all": false}',
      );
      expect(await _run(source, 'a1b2'), 'a#b2');
    });

    test('convert_unit panjang', () async {
      expect(
        await _run(
          _program('{"op": "convert_unit", "from": "km", "to": "m"}'),
          '2.5 km',
        ),
        '2500',
      );
    });

    test('convert_unit suhu', () async {
      expect(
        await _run(
          _program('{"op": "convert_unit", "from": "C", "to": "F"}'),
          '100',
        ),
        '212',
      );
    });

    test('convert_unit data', () async {
      expect(
        await _run(
          _program('{"op": "convert_unit", "from": "MiB", "to": "B"}'),
          '1 MiB',
        ),
        '1048576',
      );
    });

    test('convert_unit menolak satuan tidak sejenis', () async {
      final runtime = DslRuntime.parse(
        _program('{"op": "convert_unit", "from": "km", "to": "kg"}'),
      );
      await expectLater(
        runtime.execute(
          const TextBuffer('1'),
          const <String, Object?>{},
          _context(),
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'operation.invalid_input',
          ),
        ),
      );
    });

    test('rename key JSON rekursif', () async {
      final output = await _run(
        _program('{"op": "rename", "mapping": {"old": "new"}}'),
        '{"old": 1, "nested": [{"old": 2}]}',
      );
      expect(jsonDecode(output), <String, Object?>{
        'new': 1,
        'nested': <Object?>[
          <String, Object?>{'new': 2},
        ],
      });
    });

    test('rename menolak JSON non-objek', () async {
      final runtime = DslRuntime.parse(
        _program('{"op": "rename", "mapping": {"a": "b"}}'),
      );
      await expectLater(
        runtime.execute(
          const TextBuffer('[1]'),
          const <String, Object?>{},
          _context(),
        ),
        throwsA(isA<AppError>()),
      );
    });

    test('rename menolak key ganda', () async {
      final runtime = DslRuntime.parse(
        _program('{"op": "rename", "mapping": {"a": "b", "c": "b"}}'),
      );
      await expectLater(
        runtime.execute(
          const TextBuffer('{"a": 1, "c": 2}'),
          const <String, Object?>{},
          _context(),
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'operation.invalid_input',
          ),
        ),
      );
    });

    test('step berjalan berurutan', () async {
      final source = _program(
        '{"op": "map", "mapping": {"kucing": "cat"}},'
        '{"op": "regex_replace", "pattern": "^", "replacement": "> "}',
      );
      expect(await _run(source, 'kucing'), '> cat');
    });
  });

  group('validasi program', () {
    test('version wajib 1', () {
      expect(
        () => DslRuntime.parse('{"version": 2, "steps": []}'),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.dsl_invalid',
          ),
        ),
      );
    });

    test('steps tidak boleh kosong', () {
      expect(() => DslRuntime.parse(_program('')), throwsA(isA<AppError>()));
    });

    test('op tak dikenal ditolak', () {
      expect(
        () => DslRuntime.parse(_program('{"op": "eval", "code": "1"}')),
        throwsA(isA<AppError>()),
      );
    });

    test('field tak dikenal ditolak', () {
      expect(
        () => DslRuntime.parse(
          _program('{"op": "map", "mapping": {"a": "b"}, "shell": true}'),
        ),
        throwsA(isA<AppError>()),
      );
    });

    test('regex tidak valid ditolak saat eksekusi', () async {
      final runtime = DslRuntime.parse(
        _program('{"op": "regex_replace", "pattern": "[", "replacement": ""}'),
      );
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
            'operation.invalid_input',
          ),
        ),
      );
    });

    test('batas 200 step ditegakkan', () {
      final steps = List<String>.generate(
        201,
        (_) => '{"op": "map", "mapping": {"a": "b"}}',
      ).join(',');
      expect(() => DslRuntime.parse(_program(steps)), throwsA(isA<AppError>()));
    });
  });

  group('sandbox', () {
    test('konteks dibatalkan menghentikan eksekusi', () async {
      final token = CancellationToken();
      token.cancel();
      final runtime = DslRuntime.parse(
        _program('{"op": "map", "mapping": {"a": "b"}}'),
      );
      await expectLater(
        runtime.execute(
          const TextBuffer('a'),
          const <String, Object?>{},
          _context(cancellation: token),
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'operation.cancelled',
          ),
        ),
      );
    });

    test('FileBuffer harus dimaterialisasi', () async {
      final runtime = DslRuntime.parse(
        _program('{"op": "map", "mapping": {"a": "b"}}'),
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
    });

    test('rename menolak JSON terlalu dalam tanpa stack overflow', () async {
      final runtime = DslRuntime.parse(
        _program('{"op": "rename", "mapping": {"a": "b"}}'),
      );
      const depth = dslMaxJsonDepth + 1;
      final deep = '{"a":${'[' * depth}0${']' * depth}}';

      await expectLater(
        runtime.execute(
          TextBuffer(deep),
          const <String, Object?>{},
          _context(),
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'operation.invalid_input',
          ),
        ),
      );
    });

    test('rename tidak menghitung kurung di dalam string', () async {
      final runtime = DslRuntime.parse(
        _program('{"op": "rename", "mapping": {"a": "b"}}'),
      );
      final value = List<String>.filled(1000, '[').join();
      final output = await runtime.execute(
        TextBuffer(jsonEncode(<String, Object?>{'a': value})),
        const <String, Object?>{},
        _context(),
      );

      expect(jsonDecode(output.asText()), <String, Object?>{'b': value});
    });
  });
}
