import 'dart:convert';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/operations/format.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _run(Operation operation, String input) async {
  final output = await operation.execute(
    TextBuffer(input),
    const <String, Object?>{},
  );
  return output.asText();
}

String _jwt(Map<String, Object?> claims) {
  String segment(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment(<String, Object?>{'alg': 'HS256'})}.${segment(claims)}.sig';
}

void main() {
  test('JSON prettify dan minify', () async {
    final pretty = await _run(
      const JsonPrettifyOperation(),
      '{"a":1,"b":[2,3]}',
    );
    expect(pretty, '{\n  "a": 1,\n  "b": [\n    2,\n    3\n  ]\n}');

    final minified = await _run(const JsonMinifyOperation(), pretty);
    expect(minified, '{"a":1,"b":[2,3]}');
  });

  test('JSON invalid ditolak', () async {
    expect(
      () => _run(const JsonPrettifyOperation(), '{oops'),
      throwsA(isA<Object>()),
    );
  });

  test('JWT decode menampilkan header dan payload', () async {
    final output = await _run(
      const JwtDecodeOperation(),
      _jwt(<String, Object?>{'sub': '123'}),
    );
    expect(output, contains('"alg": "HS256"'));
    expect(output, contains('"sub": "123"'));
  });

  test('JWT tidak valid ditolak', () async {
    expect(
      () => _run(const JwtDecodeOperation(), 'not-a-jwt'),
      throwsA(isA<Object>()),
    );
  });
}
