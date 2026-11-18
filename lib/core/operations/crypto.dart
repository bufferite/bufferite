import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import '../plugin/operation.dart';
import '../plugin/operation_param.dart';

/// Operasi kripto lanjutan (F13-T09) setelah review di
/// `SECURITY_REVIEW_CRYPTO.md`.
///
/// Hanya AES-CBC (PKCS#7) dan AES-CTR; ECB sengaja tidak disediakan.
const OperationIO _textToText = OperationIO(
  input: BufferKind.text,
  output: BufferKind.text,
);

const int _maxInputBytes = 5 * 1024 * 1024;

final class AesOperation implements Operation {
  const AesOperation({required this.encrypt});

  final bool encrypt;

  @override
  String get id => encrypt ? 'core.aes_encrypt' : 'core.aes_decrypt';

  @override
  String get name => encrypt ? 'AES Encrypt' : 'AES Decrypt';

  @override
  OperationCategory get category => OperationCategory.crypto;

  @override
  List<OperationParam> get params => <OperationParam>[
    const OperationParam(
      key: 'mode',
      label: 'Mode',
      type: OperationParamType.select,
      defaultValue: 'cbc',
      options: <OperationParamOption>[
        OperationParamOption(value: 'cbc', label: 'CBC (PKCS#7)'),
        OperationParamOption(value: 'ctr', label: 'CTR (tanpa padding)'),
      ],
    ),
    const OperationParam(
      key: 'key',
      label: 'Kunci (hex)',
      type: OperationParamType.string,
      isRequired: true,
      secret: true,
      helpText: 'Hex 32/48/64 karakter (AES-128/192/256).',
    ),
    const OperationParam(
      key: 'iv',
      label: 'IV (hex)',
      type: OperationParamType.string,
      isRequired: true,
      helpText: 'Hex 32 karakter (16 byte).',
    ),
    OperationParam(
      key: 'format',
      label: encrypt ? 'Format keluaran' : 'Format masukan',
      type: OperationParamType.select,
      defaultValue: 'hex',
      options: <OperationParamOption>[
        const OperationParamOption(value: 'hex', label: 'Hex'),
        const OperationParamOption(value: 'base64', label: 'Base64'),
      ],
    ),
    if (!encrypt)
      const OperationParam(
        key: 'output',
        label: 'Keluaran',
        type: OperationParamType.select,
        defaultValue: 'text',
        options: <OperationParamOption>[
          OperationParamOption(value: 'text', label: 'Teks UTF-8'),
          OperationParamOption(value: 'hex', label: 'Hex'),
          OperationParamOption(value: 'base64', label: 'Base64'),
        ],
      ),
  ];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final mode = _stringArg(args, 'mode', defaultValue: 'cbc');
    if (mode != 'cbc' && mode != 'ctr') {
      throw _invalid('Mode AES tidak dikenal: $mode');
    }
    final key = _hexBytes(_stringArg(args, 'key'), 'Kunci');
    if (key.length != 16 && key.length != 24 && key.length != 32) {
      throw _invalid('Kunci AES harus 16, 24, atau 32 byte (hex).');
    }
    final iv = _hexBytes(_stringArg(args, 'iv'), 'IV');
    if (iv.length != 16) {
      throw _invalid('IV AES harus 16 byte (hex 32 karakter).');
    }
    final format = _stringArg(args, 'format', defaultValue: 'hex');
    if (format != 'hex' && format != 'base64') {
      throw _invalid('Format ciphertext tidak dikenal: $format');
    }

    if (encrypt) {
      final plain = Uint8List.fromList(utf8.encode(input.asText()));
      _checkSize(plain);
      final cipher = _run(plain, key, iv, mode: mode, encrypt: true);
      return TextBuffer(_encode(cipher, format));
    }

    final cipherText = _decode(
      input.asText().replaceAll(RegExp(r'\s'), ''),
      format,
    );
    _checkSize(cipherText);
    final plain = _run(cipherText, key, iv, mode: mode, encrypt: false);
    final output = _stringArg(args, 'output', defaultValue: 'text');
    if (output == 'text') {
      try {
        return TextBuffer(utf8.decode(plain));
      } on FormatException {
        throw _invalid(
          'Hasil bukan teks UTF-8. Pilih keluaran Hex atau Base64.',
        );
      }
    }
    if (output != 'hex' && output != 'base64') {
      throw _invalid('Format keluaran tidak dikenal: $output');
    }
    return TextBuffer(_encode(plain, output));
  }

  Uint8List _run(
    Uint8List data,
    Uint8List key,
    Uint8List iv, {
    required String mode,
    required bool encrypt,
  }) {
    try {
      if (mode == 'ctr') {
        final cipher = CTRStreamCipher(
          AESEngine(),
        )..init(encrypt, ParametersWithIV<KeyParameter>(KeyParameter(key), iv));
        return cipher.process(data);
      }
      final cipher =
          PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
            ..init(
              encrypt,
              PaddedBlockCipherParameters<CipherParameters?, CipherParameters?>(
                ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
                null,
              ),
            );
      return cipher.process(data);
    } on ArgumentError catch (error) {
      throw _invalid('Data/padding AES tidak valid: ${error.message}');
    }
  }
}

/// XOR dengan kunci berulang. Bukan enkripsi; hanya obfuscation.
final class XorOperation implements Operation {
  const XorOperation();

  @override
  String get id => 'core.xor';

  @override
  String get name => 'XOR';

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
    OperationParam(
      key: 'key_format',
      label: 'Format kunci',
      type: OperationParamType.select,
      defaultValue: 'text',
      options: <OperationParamOption>[
        OperationParamOption(value: 'text', label: 'Teks UTF-8'),
        OperationParamOption(value: 'hex', label: 'Hex'),
      ],
    ),
    OperationParam(
      key: 'output',
      label: 'Keluaran',
      type: OperationParamType.select,
      defaultValue: 'hex',
      options: <OperationParamOption>[
        OperationParamOption(value: 'hex', label: 'Hex'),
        OperationParamOption(value: 'base64', label: 'Base64'),
      ],
    ),
  ];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final rawKey = _stringArg(args, 'key');
    final keyFormat = _stringArg(args, 'key_format', defaultValue: 'text');
    final key = keyFormat == 'hex'
        ? _hexBytes(rawKey, 'Kunci')
        : Uint8List.fromList(utf8.encode(rawKey));
    if (key.isEmpty) {
      throw _invalid('Kunci XOR tidak boleh kosong.');
    }
    final data = Uint8List.fromList(utf8.encode(input.asText()));
    _checkSize(data);
    final out = Uint8List(data.length);
    for (var index = 0; index < data.length; index++) {
      out[index] = data[index] ^ key[index % key.length];
    }
    final output = _stringArg(args, 'output', defaultValue: 'hex');
    if (output != 'hex' && output != 'base64') {
      throw _invalid('Format keluaran tidak dikenal: $output');
    }
    return TextBuffer(_encode(out, output));
  }
}

/// Set operasi kripto lanjutan siap daftar ke registry core.
const List<Operation> cryptoOperations = <Operation>[
  AesOperation(encrypt: true),
  AesOperation(encrypt: false),
  XorOperation(),
];

String _stringArg(
  Map<String, Object?> args,
  String key, {
  String? defaultValue,
}) {
  final value = args[key];
  if (value == null) {
    if (defaultValue != null) {
      return defaultValue;
    }
    throw _invalid('Parameter "$key" wajib diisi.');
  }
  if (value is! String) {
    throw _invalid('Parameter "$key" harus string.');
  }
  return value;
}

Uint8List _hexBytes(String value, String label) {
  final text = value.replaceAll(RegExp(r'\s'), '');
  if (text.isEmpty || text.length.isOdd) {
    throw _invalid('$label hex harus berisi jumlah karakter genap.');
  }
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
    throw _invalid('$label hex mengandung karakter tidak valid.');
  }
  final bytes = Uint8List(text.length ~/ 2);
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = int.parse(
      text.substring(index * 2, index * 2 + 2),
      radix: 16,
    );
  }
  return bytes;
}

Uint8List _decode(String value, String format) {
  if (format == 'base64') {
    try {
      return base64Decode(value);
    } on FormatException {
      throw _invalid('Ciphertext Base64 tidak valid.');
    }
  }
  return _hexBytes(value, 'Ciphertext');
}

String _encode(Uint8List bytes, String format) {
  if (format == 'base64') {
    return base64Encode(bytes);
  }
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

void _checkSize(Uint8List bytes) {
  if (bytes.length > _maxInputBytes) {
    throw _invalid('Input melebihi batas $_maxInputBytes byte.');
  }
}

AppError _invalid(String message) {
  return AppError(
    category: ErrorCategory.validation,
    code: 'operation.invalid_input',
    message: message,
  );
}
