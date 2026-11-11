import 'dart:convert';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contract_harness.dart';
import 'support/fake_operations.dart';

void main() {
  const harness = OperationContractHarness();

  group('ReverseTextOperation contract', () {
    const operation = ReverseTextOperation();

    test('membalik teks', () async {
      await harness.verify(
        operation,
        const OperationContractCase(
          name: 'reverse teks',
          input: TextBuffer('Hello'),
          expectedOutput: TextBuffer('olleH'),
        ),
      );
    });

    test('menerapkan parameter uppercase', () async {
      await harness.verify(
        operation,
        const OperationContractCase(
          name: 'reverse + uppercase',
          input: TextBuffer('Hello'),
          args: <String, Object?>{'uppercase': true},
          expectedOutput: TextBuffer('OLLEH'),
        ),
      );
    });

    test('menerima input bytes', () async {
      await harness.verify(
        operation,
        OperationContractCase(
          name: 'reverse bytes',
          input: BytesBuffer(utf8.encode('abc')),
          expectedOutput: const TextBuffer('cba'),
        ),
      );
    });
  });

  group('Base64DecodeOperation contract', () {
    const operation = Base64DecodeOperation();

    test('mendekode Base64 valid', () async {
      await harness.verify(
        operation,
        OperationContractCase(
          name: 'base64 valid',
          input: const TextBuffer('SGVsbG8='),
          expectedOutput: BytesBuffer(utf8.encode('Hello')),
        ),
      );
    });

    test('mengembalikan error terstruktur untuk input invalid', () async {
      await harness.verify(
        operation,
        const OperationContractCase(
          name: 'base64 invalid',
          input: TextBuffer('%%%'),
          expectedErrorCode: 'operation.invalid_input',
        ),
      );
    });
  });
}
