import 'dart:convert';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import '../plugin/operation.dart';
import '../plugin/operation_param.dart';

/// Operasi Format untuk `core.berp` (F13-T06).
///
/// XML prettify sengaja belum diimplementasikan: parsing XML tanpa dependency
/// tambahan tidak dapat dijamin benar, dan operasi ini opsional.
const OperationIO _textToText = OperationIO(
  input: BufferKind.text,
  output: BufferKind.text,
);

AppError _invalid(String message) {
  return AppError(
    category: ErrorCategory.validation,
    code: 'operation.invalid_input',
    message: message,
  );
}

final class JsonPrettifyOperation implements Operation {
  const JsonPrettifyOperation();

  @override
  String get id => 'core.json_prettify';

  @override
  String get name => 'JSON Prettify';

  @override
  OperationCategory get category => OperationCategory.format;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    try {
      final decoded = jsonDecode(input.asText());
      return TextBuffer(const JsonEncoder.withIndent('  ').convert(decoded));
    } on FormatException {
      throw _invalid('Input bukan JSON yang valid.');
    }
  }
}

final class JsonMinifyOperation implements Operation {
  const JsonMinifyOperation();

  @override
  String get id => 'core.json_minify';

  @override
  String get name => 'JSON Minify';

  @override
  OperationCategory get category => OperationCategory.format;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    try {
      return TextBuffer(jsonEncode(jsonDecode(input.asText())));
    } on FormatException {
      throw _invalid('Input bukan JSON yang valid.');
    }
  }
}

final class JwtDecodeOperation implements Operation {
  const JwtDecodeOperation();

  @override
  String get id => 'core.jwt_decode';

  @override
  String get name => 'JWT Decode';

  @override
  OperationCategory get category => OperationCategory.format;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  /// Decode header/payload tanpa memverifikasi tanda tangan.
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final parts = input.asText().trim().split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      throw _invalid('JWT harus memiliki tiga bagian terpisah titik.');
    }

    String decode(String segment) {
      return utf8.decode(base64Url.decode(base64Url.normalize(segment)));
    }

    try {
      final header = decode(parts[0]);
      final payload = decode(parts[1]);
      return TextBuffer(
        '{\n  "header": ${_pretty(header)},\n'
        '  "payload": ${_pretty(payload)}\n}',
      );
    } on FormatException {
      throw _invalid('JWT bukan Base64URL yang valid.');
    }
  }

  String _pretty(String json) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(json));
    } on FormatException {
      return json;
    }
  }
}
