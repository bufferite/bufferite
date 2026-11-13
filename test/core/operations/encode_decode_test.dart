import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/operations/encode_decode.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _run(Object operation, String input) async {
  final dynamic op = operation;
  final Buffer output =
      await op.execute(TextBuffer(input), const <String, Object?>{}) as Buffer;
  return output.asText();
}

void main() {
  test('Base64 encode/decode round-trip', () async {
    final encoded = await _run(const Base64EncodeOperation(), 'Hello');
    expect(encoded, 'SGVsbG8=');
    expect(await _run(const Base64DecodeOperation(), encoded), 'Hello');
  });

  test('Base64 decode invalid menghasilkan error terstruktur', () async {
    expect(
      () => _run(const Base64DecodeOperation(), '%%%'),
      throwsA(
        isA<Object>().having(
          (error) => '$error',
          'message',
          contains('operation.invalid_input'),
        ),
      ),
    );
  });

  test('Hex encode/decode round-trip', () async {
    final encoded = await _run(const HexEncodeOperation(), 'AB');
    expect(encoded, '4142');
    expect(await _run(const HexDecodeOperation(), encoded), 'AB');
  });

  test('Hex decode menolak panjang ganjil', () async {
    expect(
      () => _run(const HexDecodeOperation(), 'ABC'),
      throwsA(isA<Object>()),
    );
  });

  test('URL encode/decode round-trip', () async {
    final encoded = await _run(const UrlEncodeOperation(), 'a b&c');
    expect(encoded, 'a%20b%26c');
    expect(await _run(const UrlDecodeOperation(), encoded), 'a b&c');
  });

  test('HTML entity encode/decode round-trip', () async {
    final encoded = await _run(
      const HtmlEntityEncodeOperation(),
      '<a href="x">&',
    );
    expect(encoded, '&lt;a href=&quot;x&quot;&gt;&amp;');
    expect(
      await _run(const HtmlEntityDecodeOperation(), encoded),
      '<a href="x">&',
    );
  });

  test('Base32 encode/decode round-trip', () async {
    final encoded = await _run(const Base32EncodeOperation(), 'Hello');
    expect(encoded, 'JBSWY3DP');
    expect(await _run(const Base32DecodeOperation(), encoded), 'Hello');
  });
}
