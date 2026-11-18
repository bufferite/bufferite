// ignore_for_file: prefer_const_constructors
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import '../plugin/operation.dart';
import '../plugin/operation_param.dart';

/// Operasi hash/kripto dasar untuk `core.berp` (F13-T05).
///
/// MD5 dan SHA-1 disediakan hanya untuk kompatibilitas, bukan keamanan.
const OperationIO _textToText = OperationIO(
  input: BufferKind.text,
  output: BufferKind.text,
);

final class HashOperation implements Operation {
  const HashOperation(this._algorithm, this._id, this._name);

  final Hash _algorithm;
  final String _id;
  final String _name;

  @override
  String get id => _id;

  @override
  String get name => _name;

  @override
  OperationCategory get category => OperationCategory.crypto;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    return TextBuffer(
      _algorithm.convert(utf8.encode(input.asText())).toString(),
    );
  }
}

final class HmacOperation implements Operation {
  const HmacOperation(this._algorithm, this._id, this._name);

  final Hash _algorithm;
  final String _id;
  final String _name;

  @override
  String get id => _id;

  @override
  String get name => _name;

  @override
  OperationCategory get category => OperationCategory.crypto;

  @override
  List<OperationParam> get params => const <OperationParam>[
    OperationParam(
      key: 'key',
      label: 'Kunci',
      type: OperationParamType.string,
      isRequired: true,
    ),
  ];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final key = args['key'];
    if (key is! String || key.isEmpty) {
      throw AppError(
        category: ErrorCategory.validation,
        code: 'operation.invalid_input',
        message: 'Parameter "key" wajib diisi.',
      );
    }
    final hmac = Hmac(_algorithm, utf8.encode(key));
    return TextBuffer(hmac.convert(utf8.encode(input.asText())).toString());
  }
}

/// Set operasi hash siap daftar ke registry core.
final List<Operation> hashOperations = <Operation>[
  HashOperation(md5, 'core.md5', 'MD5'),
  HashOperation(sha1, 'core.sha1', 'SHA-1'),
  HashOperation(sha256, 'core.sha256', 'SHA-256'),
  HashOperation(sha512, 'core.sha512', 'SHA-512'),
  HmacOperation(sha1, 'core.hmac_sha1', 'HMAC-SHA1'),
  HmacOperation(sha256, 'core.hmac_sha256', 'HMAC-SHA256'),
  HmacOperation(sha512, 'core.hmac_sha512', 'HMAC-SHA512'),
];
