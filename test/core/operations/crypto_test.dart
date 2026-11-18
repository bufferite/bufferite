import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/operations/crypto.dart';
import 'package:bufferite/core/operations/hash.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:flutter_test/flutter_test.dart';

const aesKey = '2b7e151628aed2a6abf7158809cf4f3c';
const aesIv = 'f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff';

Future<String> _run(
  Operation operation,
  String input,
  Map<String, Object?> args,
) async {
  final buffer = await operation.execute(TextBuffer(input), args);
  return buffer.asText();
}

Map<String, Object?> _aesArgs({String mode = 'cbc', String format = 'hex'}) {
  return <String, Object?>{
    'mode': mode,
    'key': aesKey,
    'iv': aesIv,
    'format': format,
  };
}

void main() {
  group('AES', () {
    const encrypt = AesOperation(encrypt: true);
    const decrypt = AesOperation(encrypt: false);

    test('CBC + PKCS#7 roundtrip hex', () async {
      final cipherText = await _run(encrypt, 'Bufferite', _aesArgs());
      expect(cipherText, hasLength(32));
      final plain = await _run(decrypt, cipherText, _aesArgs());
      expect(plain, 'Bufferite');
    });

    test('CBC roundtrip base64', () async {
      final cipherText = await _run(
        encrypt,
        'Racik data',
        _aesArgs(format: 'base64'),
      );
      final plain = await _run(decrypt, cipherText, _aesArgs(format: 'base64'));
      expect(plain, 'Racik data');
    });

    test('CTR cocok dengan keystream NIST SP 800-38A', () async {
      // Plaintext 16 byte NUL; ciphertext = keystream AES-CTR NIST.
      final cipherText = await _run(
        encrypt,
        '\x00' * 16,
        _aesArgs(mode: 'ctr'),
      );
      expect(cipherText, 'ec8cdf7398607cb0f2d21675ea9ea1e4');
    });

    test('CTR roundtrip dengan UTF-8', () async {
      final cipherText = await _run(
        encrypt,
        'halo dunia',
        _aesArgs(mode: 'ctr'),
      );
      final plain = await _run(decrypt, cipherText, _aesArgs(mode: 'ctr'));
      expect(plain, 'halo dunia');
    });

    test('kunci/IV tidak valid ditolak', () async {
      expect(
        () => encrypt.execute(const TextBuffer('x'), <String, Object?>{
          'key': 'abcd',
          'iv': aesIv,
        }),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'operation.invalid_input',
          ),
        ),
      );
      expect(
        () => encrypt.execute(const TextBuffer('x'), <String, Object?>{
          'key': aesKey,
          'iv': '00',
        }),
        throwsA(isA<AppError>()),
      );
    });

    test('base64 rusak ditolak', () async {
      expect(
        () => decrypt.execute(
          const TextBuffer('bukan base64!'),
          _aesArgs(format: 'base64'),
        ),
        throwsA(isA<AppError>()),
      );
    });

    test('hasil non-UTF-8 memberi saran format hex', () async {
      expect(
        () => decrypt.execute(
          const TextBuffer('deadbeef'),
          _aesArgs(mode: 'ctr'),
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
  });

  group('XOR', () {
    const xor = XorOperation();

    test('XOR teks ke hex', () async {
      expect(await _run(xor, 'A', <String, Object?>{'key': 'B'}), '03');
    });

    test('XOR kunci hex', () async {
      expect(
        await _run(xor, 'A', <String, Object?>{
          'key': 'ff',
          'key_format': 'hex',
        }),
        'be',
      );
    });

    test('XOR keluaran base64', () async {
      expect(
        await _run(xor, 'A', <String, Object?>{'key': 'B', 'output': 'base64'}),
        'Aw==',
      );
    });

    test('kunci kosong ditolak', () async {
      expect(
        () => xor.execute(const TextBuffer('x'), <String, Object?>{'key': ''}),
        throwsA(isA<AppError>()),
      );
    });
  });

  group('HMAC varian', () {
    test('HMAC-SHA1 vektor referensi', () async {
      final op = hashOperations.whereType<HmacOperation>().firstWhere(
        (operation) => operation.id == 'core.hmac_sha1',
      );
      expect(
        await _run(
          op,
          'The quick brown fox jumps over the lazy dog',
          <String, Object?>{'key': 'key'},
        ),
        'de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9',
      );
    });

    test('HMAC-SHA512 vektor referensi', () async {
      final op = hashOperations.whereType<HmacOperation>().firstWhere(
        (operation) => operation.id == 'core.hmac_sha512',
      );
      expect(
        await _run(
          op,
          'The quick brown fox jumps over the lazy dog',
          <String, Object?>{'key': 'key'},
        ),
        'b42af09057bac1e2d41708e48a902e09b5ff7f12ab428a4fe86653c73dd248fb'
        '82f948a549f7b791a5b41915ee4d1ec3935357e4e2317250d0372afa2ebeeb3a',
      );
    });
  });
}
