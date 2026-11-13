import 'dart:math';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import '../plugin/operation.dart';
import '../plugin/operation_param.dart';

/// Operasi acak `core.berp` (F14-T05).
///
/// Semua operasi memakai `Random.secure()` (CSPRNG), bukan `Random()` biasa.
const OperationIO _toText = OperationIO(
  input: BufferKind.text,
  output: BufferKind.text,
);

const int maxRandomBytes = 1024 * 1024;

AppError _invalid(String message) {
  return AppError(
    category: ErrorCategory.validation,
    code: 'operation.invalid_input',
    message: message,
  );
}

int _resolveLength(Map<String, Object?> args) {
  final length = args['length'];
  if (length is! int || length <= 0) {
    throw _invalid('Parameter "length" harus bilangan bulat positif.');
  }
  if (length > maxRandomBytes) {
    throw _invalid('Panjang melebihi batas $maxRandomBytes byte.');
  }
  return length;
}

final class RandomHexOperation implements Operation {
  const RandomHexOperation();

  @override
  String get id => 'core.random_hex';

  @override
  String get name => 'Random Hex';

  @override
  OperationCategory get category => OperationCategory.crypto;

  @override
  List<OperationParam> get params => const <OperationParam>[
    OperationParam(
      key: 'length',
      label: 'Panjang (byte)',
      type: OperationParamType.integer,
      defaultValue: 16,
      min: 1,
    ),
  ];

  @override
  OperationIO get io => _toText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final length = _resolveLength(args);
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return TextBuffer(buffer.toString());
  }
}

final class RandomBytesOperation implements Operation {
  const RandomBytesOperation();

  @override
  String get id => 'core.random_bytes';

  @override
  String get name => 'Random Bytes';

  @override
  OperationCategory get category => OperationCategory.crypto;

  @override
  List<OperationParam> get params => const <OperationParam>[
    OperationParam(
      key: 'length',
      label: 'Panjang (byte)',
      type: OperationParamType.integer,
      defaultValue: 16,
      min: 1,
    ),
  ];

  @override
  OperationIO get io => _toText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final length = _resolveLength(args);
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(String.fromCharCode(random.nextInt(256)));
    }
    return TextBuffer(buffer.toString());
  }
}
