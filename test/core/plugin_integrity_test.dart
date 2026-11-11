import 'dart:convert';

import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/plugin_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PluginIntegrity', () {
    test('menghitung SHA-256 yang dikenal', () {
      expect(
        PluginIntegrity.sha256Hex(const <int>[]),
        'e3b0c44298fc1c149afbf4c8996fb924'
        '27ae41e4649b934ca495991b7852b855',
      );
      expect(
        PluginIntegrity.sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223'
        'b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('menerima hash cocok tanpa memedulikan kapitalisasi', () {
      final bytes = utf8.encode('bufferite');
      final hash = PluginIntegrity.sha256Hex(bytes).toUpperCase();
      expect(
        () => PluginIntegrity.verifyOrThrow(bytes: bytes, expected: hash),
        returnsNormally,
      );
    });

    test('menolak paket yang dimodifikasi', () {
      final original = utf8.encode('original package bytes');
      final modified = utf8.encode('modified package bytes');
      final hash = PluginIntegrity.sha256Hex(original);

      expect(
        () => PluginIntegrity.verifyOrThrow(
          bytes: modified,
          expected: hash,
          subject: 'package.berp',
        ),
        throwsA(
          isA<AppError>()
              .having((error) => error.code, 'code', 'plugin.verify_failed')
              .having(
                (error) => error.details['subject'],
                'subject',
                'package.berp',
              ),
        ),
      );
    });

    test('menolak format hash invalid', () {
      expect(
        () => PluginIntegrity.verifyOrThrow(
          bytes: const <int>[1],
          expected: 'not-a-hash',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.hash_invalid',
          ),
        ),
      );
      expect(PluginIntegrity.isValidHash('abc'), isFalse);
      expect(
        PluginIntegrity.isValidHash(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        ),
        isTrue,
      );
    });
  });
}
