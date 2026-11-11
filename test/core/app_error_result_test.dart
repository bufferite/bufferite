import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppError', () {
    const error = AppError(
      category: ErrorCategory.runtime,
      code: 'runtime.timeout',
      message: 'Operasi melewati batas waktu.',
      pluginId: 'com.contoh.pack',
      stepId: 'step-1',
      details: <String, Object?>{'timeoutMs': 2000},
    );

    test('round-trip JSON', () {
      final decoded = AppError.fromJson(error.toJson());

      expect(decoded.category, error.category);
      expect(decoded.code, error.code);
      expect(decoded.message, error.message);
      expect(decoded.pluginId, error.pluginId);
      expect(decoded.stepId, error.stepId);
      expect(decoded.details, error.details);
    });

    test('menolak JSON tidak valid', () {
      expect(
        () => AppError.fromJson(<String, Object?>{
          'category': 'runtime',
          'code': 'x',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppError.fromJson(<String, Object?>{
          'category': 'unknown',
          'code': 'x',
          'message': 'x',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('copyWith mempertahankan field yang tidak diubah', () {
      final copy = error.copyWith(stepId: 'step-2');

      expect(copy.stepId, 'step-2');
      expect(copy.code, error.code);
      expect(copy.pluginId, error.pluginId);
    });
  });

  group('Result', () {
    test('Ok membawa nilai dan map/flatMap bekerja', () {
      const result = Ok<int>(2);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 2);
      expect(result.errorOrNull, isNull);
      expect(result.map((value) => value * 2).valueOrNull, 4);
      expect(
        result.flatMap((value) => Ok<String>('nilai $value')).valueOrNull,
        'nilai 2',
      );
    });

    test('Err membawa error dan map tidak dijalankan', () {
      const error = AppError(
        category: ErrorCategory.validation,
        code: 'recipe.invalid',
        message: 'Recipe tidak valid.',
      );
      const result = Err<int>(error);

      var mapped = false;
      final mappedResult = result.map((value) {
        mapped = true;
        return value;
      });

      expect(result.isSuccess, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull, error);
      expect(mapped, isFalse);
      expect(mappedResult.errorOrNull, error);
    });

    test('when memilih cabang sesuai hasil', () {
      const success = Ok<String>('ok');
      const failure = Err<String>(
        AppError(
          category: ErrorCategory.storage,
          code: 'storage.read_failed',
          message: 'Gagal membaca.',
        ),
      );

      expect(
        success.when(success: (value) => value, failure: (_) => 'gagal'),
        'ok',
      );
      expect(
        failure.when(success: (value) => value, failure: (_) => 'gagal'),
        'gagal',
      );
    });
  });
}
