import 'dart:convert';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_param.dart';

final class ReverseTextOperation implements Operation {
  const ReverseTextOperation();

  @override
  String get id => 'test.reverse';

  @override
  String get name => 'Reverse Text';

  @override
  OperationCategory get category => OperationCategory.utility;

  @override
  List<OperationParam> get params => const <OperationParam>[
    OperationParam(
      key: 'uppercase',
      label: 'Uppercase',
      type: OperationParamType.boolean,
      defaultValue: false,
    ),
  ];

  @override
  OperationIO get io =>
      const OperationIO(input: BufferKind.text, output: BufferKind.text);

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final reversed = input.asText().split('').reversed.join();
    final uppercase = args['uppercase'] == true;
    return TextBuffer(uppercase ? reversed.toUpperCase() : reversed);
  }
}

final class Base64DecodeOperation implements Operation {
  const Base64DecodeOperation();

  @override
  String get id => 'test.base64_decode';

  @override
  String get name => 'Base64 Decode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io =>
      const OperationIO(input: BufferKind.text, output: BufferKind.bytes);

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    try {
      return BytesBuffer(base64Decode(input.asText()));
    } on FormatException catch (error) {
      throw AppError(
        category: ErrorCategory.validation,
        code: 'operation.invalid_input',
        message: 'Input Base64 tidak valid.',
        details: <String, Object?>{'error': error.message},
      );
    }
  }
}
