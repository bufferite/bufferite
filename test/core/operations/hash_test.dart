// ignore_for_file: prefer_const_constructors
import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/operations/hash.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _run(Operation operation, String input) async {
  final output = await operation.execute(
    TextBuffer(input),
    operation is HmacOperation
        ? const <String, Object?>{'key': 'key'}
        : const <String, Object?>{},
  );
  return output.asText();
}

void main() {
  test('hash vektor dikenal', () async {
    expect(
      await _run(HashOperation(md5, 'core.md5', 'MD5'), 'abc'),
      '900150983cd24fb0d6963f7d28e17f72',
    );
    expect(
      await _run(HashOperation(sha1, 'core.sha1', 'SHA-1'), 'abc'),
      'a9993e364706816aba3e25717850c26c9cd0d89d',
    );
    expect(
      await _run(HashOperation(sha256, 'core.sha256', 'SHA-256'), 'abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      await _run(HashOperation(sha512, 'core.sha512', 'SHA-512'), 'abc'),
      'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a'
      '2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f',
    );
  });

  test('HMAC-SHA256 vektor dikenal', () async {
    final result = await _run(
      const HmacOperation(sha256, 'core.hmac_sha256', 'HMAC-SHA256'),
      'The quick brown fox jumps over the lazy dog',
    );
    expect(
      result,
      'f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8',
    );
  });

  test('HMAC tanpa key menolak', () async {
    expect(
      () => const HmacOperation(
        sha256,
        'core.hmac_sha256',
        'HMAC-SHA256',
      ).execute(const TextBuffer('x'), const <String, Object?>{}),
      throwsA(isA<Object>()),
    );
  });

  test('daftar operasi hash lengkap', () {
    expect(hashOperations.map((operation) => operation.id), <String>[
      'core.md5',
      'core.sha1',
      'core.sha256',
      'core.sha512',
      'core.hmac_sha1',
      'core.hmac_sha256',
      'core.hmac_sha512',
    ]);
  });
}
