import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_param.dart';
import 'package:flutter_test/flutter_test.dart';

final class OperationContractCase {
  const OperationContractCase({
    required this.name,
    required this.input,
    this.args = const <String, Object?>{},
    this.expectedOutput,
    this.expectedErrorCode,
  });

  final String name;
  final Buffer input;
  final Map<String, Object?> args;
  final Buffer? expectedOutput;
  final String? expectedErrorCode;
}

/// Harness contract test yang dipakai ulang oleh operasi core dan plugin.
final class OperationContractHarness {
  const OperationContractHarness();

  Future<void> verify(
    Operation operation,
    OperationContractCase testCase,
  ) async {
    final resolved = resolveOperationArgs(operation.params, testCase.args);
    expect(
      resolved.isSuccess,
      isTrue,
      reason:
          '${testCase.name}: args gagal divalidasi '
          '(${resolved.errorOrNull?.code}).',
    );

    final args = resolved.valueOrNull ?? const <String, Object?>{};
    final inputBefore = testCase.input.toJson();

    if (testCase.expectedErrorCode != null) {
      await expectLater(
        operation.execute(testCase.input, args),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            testCase.expectedErrorCode,
          ),
        ),
        reason: testCase.name,
      );
    } else {
      expect(
        testCase.expectedOutput,
        isNotNull,
        reason: '${testCase.name}: expectedOutput wajib diisi.',
      );
      final output = await operation.execute(testCase.input, args);
      expect(output, testCase.expectedOutput, reason: testCase.name);
    }

    expect(
      testCase.input.toJson(),
      inputBefore,
      reason: '${testCase.name}: operasi tidak boleh memutasi input.',
    );
  }
}
