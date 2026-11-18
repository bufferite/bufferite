import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/engine/pipeline.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/runtime/lua_runtime.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

SandboxContext _context({CancellationToken? cancellation}) {
  return SandboxContext(
    pluginId: 'com.example.lua',
    operationId: 'lua.transform',
    config: SandboxConfig.defaults,
    cancellation: cancellation,
  );
}

Future<String> _run(
  String source,
  String input, {
  Map<String, Object?> args = const <String, Object?>{},
  SandboxContext? context,
}) async {
  final runtime = LuaRuntime(source);
  final out = await runtime.execute(
    TextBuffer(input),
    args,
    context ?? _context(),
  );
  return out.asText();
}

void main() {
  test('transform mengembalikan string', () async {
    expect(
      await _run(
        'function transform(input, args) return string.upper(input) end',
        'abc',
      ),
      'ABC',
    );
  });

  test('output print ditangkap', () async {
    expect(
      await _run(
        'function transform(input, args) print("x") print(input) end',
        'baris',
      ),
      'x\nbaris\n',
    );
  });

  test('args tabel tersedia', () async {
    expect(
      await _run(
        'function transform(input, args) return args.prefix .. input end',
        'dunia',
        args: <String, Object?>{'prefix': 'halo '},
      ),
      'halo dunia',
    );
  });

  test('unicode dan karakter khusus utuh', () async {
    const input = 'baris1\n"kutip" ✓ 你好';
    expect(
      await _run('function transform(input) return input end', input),
      input,
    );
  });

  test('sandbox menghapus io dan os.execute', () async {
    expect(
      await _run(
        'function transform() return tostring(io) .. "," .. '
            'tostring(os.execute) end',
        'x',
      ),
      'nil,nil',
    );
  });

  test('akses terlarang menghasilkan error terstruktur', () async {
    await expectLater(
      _run(
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
  });

  test('transform tidak ada memberi error terstruktur', () async {
    await expectLater(
      _run('x = 1', 'x'),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.lua_error',
        ),
      ),
    );
  });

  test('syntax error memberi error terstruktur', () async {
    await expectLater(
      _run('function transform( end', 'x'),
      throwsA(isA<AppError>()),
    );
  });

  test('konteks dibatalkan menghentikan eksekusi', () async {
    final token = CancellationToken()..cancel();
    await expectLater(
      _run(
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
  });

  test('FileBuffer harus dimaterialisasi', () async {
    final runtime = LuaRuntime('function transform(input) return input end');
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
}
