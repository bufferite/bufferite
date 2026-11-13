import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/operations/safe_regex.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replace biasa bekerja', () {
    expect(
      SafeRegex.replaceAll('a-b-c', pattern: '-', replacement: '_'),
      'a_b_c',
    );
  });

  test('menolak pola terlalu panjang', () {
    expect(
      () => SafeRegex.replaceAll(
        'x',
        pattern: 'a' * (SafeRegex.maxPatternLength + 1),
        replacement: '',
      ),
      throwsA(isA<AppError>()),
    );
  });

  test('menolak kuantifier bersarang (ReDoS)', () {
    for (final pattern in <String>['(a+)+', '(.*)*', r'(\d+){2,}']) {
      expect(
        () => SafeRegex.replaceAll(
          'aaaaaaaaaaaaaaaaaaaaaaaaa',
          pattern: pattern,
          replacement: '',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.message,
            'message',
            contains('ReDoS'),
          ),
        ),
        reason: pattern,
      );
    }
  });

  test('menolak pola regex tidak valid', () {
    expect(
      () => SafeRegex.replaceAll('x', pattern: '[', replacement: ''),
      throwsA(isA<AppError>()),
    );
  });

  test('ignore case dihormati', () {
    expect(
      SafeRegex.replaceAll(
        'aXbXc',
        pattern: 'x',
        replacement: '',
        ignoreCase: true,
      ),
      'abc',
    );
  });
}
