import 'dart:convert';
import 'dart:typed_data';

import '../error/app_error.dart';

enum BufferKind {
  text,
  bytes,
  file;

  static BufferKind parse(Object? value) {
    if (value is String) {
      for (final kind in values) {
        if (kind.name == value) {
          return kind;
        }
      }
    }
    throw AppError(
      category: ErrorCategory.validation,
      code: 'operation.io_invalid',
      message: 'Tipe buffer I/O tidak dikenal: $value',
    );
  }
}

/// Nilai data immutable yang mengalir melalui pipeline.
sealed class Buffer {
  const Buffer();

  BufferKind get kind;

  /// Panjang data dalam byte. Untuk [FileBuffer] memakai ukuran yang diketahui.
  int get length;

  Uint8List asBytes({Encoding? encoding});

  String asText({Encoding? encoding});

  /// Salinan yang dipotong untuk preview UI. Tidak boleh membaca file besar.
  Buffer preview({int maxBytes = 4096});

  Map<String, Object?> toJson();

  factory Buffer.fromJson(Map<String, Object?> json) {
    final type = json['type'];
    if (type is! String) {
      throw _invalid(
        'buffer.type_missing',
        'Buffer harus memiliki field type.',
      );
    }

    switch (type) {
      case 'text':
        final value = json['value'];
        if (value is! String) {
          throw _invalid(
            'buffer.value_invalid',
            'Buffer teks harus memiliki value bertipe string.',
          );
        }
        final encoding = _decodeEncoding(json['encoding']);
        return TextBuffer(value, encoding: encoding);
      case 'bytes':
        final encoded = json['base64'];
        if (encoded is! String) {
          throw _invalid(
            'buffer.bytes_invalid',
            'Buffer bytes harus memiliki base64 bertipe string.',
          );
        }
        try {
          return BytesBuffer(base64Decode(encoded));
        } on FormatException catch (error) {
          throw _invalid(
            'buffer.base64_invalid',
            'Base64 buffer tidak valid.',
            <String, Object?>{'error': error.message},
          );
        }
      case 'file':
        final path = json['path'];
        final name = json['name'];
        final size = json['size'];
        if (path is! String || name is! String) {
          throw _invalid(
            'buffer.file_invalid',
            'Buffer file harus memiliki path dan name bertipe string.',
          );
        }
        if (size != null && size is! int) {
          throw _invalid(
            'buffer.file_size_invalid',
            'Ukuran file harus bertipe integer.',
          );
        }
        return FileBuffer(path: path, name: name, size: size as int?);
      default:
        throw _invalid(
          'buffer.type_unknown',
          'Tipe buffer tidak dikenal: $type',
        );
    }
  }
}

final class TextBuffer extends Buffer {
  const TextBuffer(this.value, {this.encoding = utf8});

  final String value;
  final Encoding encoding;

  @override
  BufferKind get kind => BufferKind.text;

  @override
  int get length => asBytes().length;

  @override
  Uint8List asBytes({Encoding? encoding}) {
    return Uint8List.fromList((encoding ?? this.encoding).encode(value));
  }

  @override
  String asText({Encoding? encoding}) => value;

  @override
  Buffer preview({int maxBytes = 4096}) {
    _checkPreviewLimit(maxBytes);
    if (value.length <= maxBytes) {
      return this;
    }
    return TextBuffer(value.substring(0, maxBytes), encoding: encoding);
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': 'text',
      'value': value,
      if (encoding != utf8) 'encoding': encoding.name,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is TextBuffer &&
        other.value == value &&
        other.encoding.name == encoding.name;
  }

  @override
  int get hashCode => Object.hash(value, encoding.name);
}

final class BytesBuffer extends Buffer {
  BytesBuffer(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;

  @override
  BufferKind get kind => BufferKind.bytes;

  @override
  int get length => _bytes.length;

  @override
  Uint8List asBytes({Encoding? encoding}) => Uint8List.fromList(_bytes);

  @override
  String asText({Encoding? encoding}) {
    final codec = encoding ?? utf8;
    try {
      return codec.decode(_bytes);
    } on FormatException catch (error) {
      throw AppError(
        category: ErrorCategory.validation,
        code: 'buffer.decode_failed',
        message: 'Byte tidak dapat didekode dengan ${codec.name}.',
        details: <String, Object?>{'error': error.message},
      );
    }
  }

  @override
  Buffer preview({int maxBytes = 4096}) {
    _checkPreviewLimit(maxBytes);
    if (_bytes.length <= maxBytes) {
      return this;
    }
    return BytesBuffer(Uint8List.sublistView(_bytes, 0, maxBytes));
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'type': 'bytes', 'base64': base64Encode(_bytes)};
  }

  @override
  bool operator ==(Object other) {
    if (other is! BytesBuffer || other._bytes.length != _bytes.length) {
      return false;
    }
    for (var index = 0; index < _bytes.length; index++) {
      if (other._bytes[index] != _bytes[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_bytes);
}

final class FileBuffer extends Buffer {
  const FileBuffer({required this.path, required this.name, this.size});

  final String path;
  final String name;
  final int? size;

  @override
  BufferKind get kind => BufferKind.file;

  @override
  int get length => size ?? 0;

  @override
  Uint8List asBytes({Encoding? encoding}) {
    throw UnsupportedError(
      'FileBuffer harus dimaterialisasi oleh engine setelah izin file:read.',
    );
  }

  @override
  String asText({Encoding? encoding}) {
    throw UnsupportedError(
      'FileBuffer harus dimaterialisasi oleh engine setelah izin file:read.',
    );
  }

  @override
  Buffer preview({int maxBytes = 4096}) => this;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': 'file',
      'path': path,
      'name': name,
      if (size != null) 'size': size,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is FileBuffer &&
        other.path == path &&
        other.name == name &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(path, name, size);
}

Encoding _decodeEncoding(Object? value) {
  if (value == null) {
    return utf8;
  }
  if (value is! String) {
    throw _invalid('buffer.encoding_invalid', 'Encoding harus bertipe string.');
  }
  final encoding = Encoding.getByName(value);
  if (encoding == null) {
    throw _invalid('buffer.encoding_unknown', 'Encoding tidak dikenal: $value');
  }
  return encoding;
}

AppError _invalid(
  String code,
  String message, [
  Map<String, Object?> details = const <String, Object?>{},
]) {
  return AppError(
    category: ErrorCategory.validation,
    code: code,
    message: message,
    details: details,
  );
}

void _checkPreviewLimit(int maxBytes) {
  if (maxBytes <= 0) {
    throw ArgumentError.value(maxBytes, 'maxBytes', 'Harus lebih dari 0.');
  }
}
