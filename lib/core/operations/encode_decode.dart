import 'dart:convert';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import '../plugin/operation.dart';
import '../plugin/operation_param.dart';

/// Operasi Encode/Decode dasar untuk `core.berp` (F13-T04).
///
/// Semua operasi memakai input/output teks dan mengembalikan
/// `operation.invalid_input` terstruktur saat data tidak valid.

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

final class Base64EncodeOperation implements Operation {
  const Base64EncodeOperation();

  @override
  String get id => 'core.base64_encode';

  @override
  String get name => 'Base64 Encode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    return TextBuffer(base64.encode(utf8.encode(input.asText())));
  }
}

final class Base64DecodeOperation implements Operation {
  const Base64DecodeOperation();

  @override
  String get id => 'core.base64_decode';

  @override
  String get name => 'Base64 Decode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    try {
      return TextBuffer(utf8.decode(base64.decode(input.asText().trim())));
    } on FormatException {
      throw _invalid('Input bukan Base64 yang valid.');
    }
  }
}

final class HexEncodeOperation implements Operation {
  const HexEncodeOperation();

  @override
  String get id => 'core.hex_encode';

  @override
  String get name => 'Hex Encode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final bytes = utf8.encode(input.asText());
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return TextBuffer(buffer.toString());
  }
}

final class HexDecodeOperation implements Operation {
  const HexDecodeOperation();

  @override
  String get id => 'core.hex_decode';

  @override
  String get name => 'Hex Decode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final text = input.asText().trim().replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty || text.length.isOdd) {
      throw _invalid('Input Hex harus berjumlah genap.');
    }
    final bytes = <int>[];
    for (var i = 0; i < text.length; i += 2) {
      final value = int.tryParse(text.substring(i, i + 2), radix: 16);
      if (value == null) {
        throw _invalid('Input Hex memuat karakter tidak valid.');
      }
      bytes.add(value);
    }
    try {
      return TextBuffer(utf8.decode(bytes));
    } on FormatException {
      throw _invalid('Byte Hex bukan UTF-8 yang valid.');
    }
  }
}

final class UrlEncodeOperation implements Operation {
  const UrlEncodeOperation();

  @override
  String get id => 'core.url_encode';

  @override
  String get name => 'URL Encode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    return TextBuffer(Uri.encodeComponent(input.asText()));
  }
}

final class UrlDecodeOperation implements Operation {
  const UrlDecodeOperation();

  @override
  String get id => 'core.url_decode';

  @override
  String get name => 'URL Decode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    try {
      return TextBuffer(Uri.decodeComponent(input.asText()));
    } on ArgumentError {
      throw _invalid('Input URL tidak valid.');
    }
  }
}

final class HtmlEntityEncodeOperation implements Operation {
  const HtmlEntityEncodeOperation();

  static const Map<String, String> _entities = <String, String>{
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  };

  @override
  String get id => 'core.html_entity_encode';

  @override
  String get name => 'HTML Entity Encode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final text = input.asText();
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_entities[char] ?? char);
    }
    return TextBuffer(buffer.toString());
  }
}

final class HtmlEntityDecodeOperation implements Operation {
  const HtmlEntityDecodeOperation();

  static const Map<String, String> _entities = <String, String>{
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
  };

  @override
  String get id => 'core.html_entity_decode';

  @override
  String get name => 'HTML Entity Decode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    var text = input.asText();
    for (final entry in _entities.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return TextBuffer(text);
  }
}

/// Base32 (RFC 4648, tanpa padding) untuk kompatibilitas CyberChef-like.
final class Base32EncodeOperation implements Operation {
  const Base32EncodeOperation();

  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  @override
  String get id => 'core.base32_encode';

  @override
  String get name => 'Base32 Encode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final bytes = utf8.encode(input.asText());
    final buffer = StringBuffer();
    var bits = 0;
    var value = 0;
    for (final byte in bytes) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        buffer.write(_alphabet[(value >> bits) & 31]);
      }
    }
    if (bits > 0) {
      buffer.write(_alphabet[(value << (5 - bits)) & 31]);
    }
    return TextBuffer(buffer.toString());
  }
}

final class Base32DecodeOperation implements Operation {
  const Base32DecodeOperation();

  @override
  String get id => 'core.base32_decode';

  @override
  String get name => 'Base32 Decode';

  @override
  OperationCategory get category => OperationCategory.encodeDecode;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final text = input.asText().trim().replaceAll('=', '').toUpperCase();
    final bytes = <int>[];
    var bits = 0;
    var value = 0;
    for (final rune in text.runes) {
      final index = Base32EncodeOperation._alphabet.indexOf(
        String.fromCharCode(rune),
      );
      if (index < 0) {
        throw _invalid('Input Base32 memuat karakter tidak valid.');
      }
      value = (value << 5) | index;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        bytes.add((value >> bits) & 0xFF);
      }
    }
    try {
      return TextBuffer(utf8.decode(bytes));
    } on FormatException {
      throw _invalid('Byte Base32 bukan UTF-8 yang valid.');
    }
  }
}
