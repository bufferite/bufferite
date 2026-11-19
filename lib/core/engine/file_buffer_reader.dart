import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../error/app_error.dart';
import 'buffer.dart';

/// Membaca [FileBuffer] secara bertahap ke satu alokasi byte.
///
/// File yang lebih besar dari [memoryLimitBytes] ditolak sebelum alokasi agar
/// aplikasi tidak kehabisan memori. Pembacaan memakai [RandomAccessFile.readInto]
/// sehingga tidak membuat salinan per chunk.
final class FileBufferReader {
  FileBufferReader({
    required this.memoryLimitBytes,
    this.chunkBytes = 64 * 1024,
  }) {
    if (memoryLimitBytes <= 0) {
      throw ArgumentError.value(
        memoryLimitBytes,
        'memoryLimitBytes',
        'Batas memori harus lebih dari nol.',
      );
    }
    if (chunkBytes <= 0) {
      throw ArgumentError.value(
        chunkBytes,
        'chunkBytes',
        'Ukuran chunk harus lebih dari nol.',
      );
    }
  }

  final int memoryLimitBytes;
  final int chunkBytes;

  /// Mengembalikan buffer apa adanya bila bukan file, atau [BytesBuffer] hasil
  /// pembacaan file bila input adalah [FileBuffer].
  Future<Buffer> materialize(Buffer buffer) async {
    if (buffer is! FileBuffer) {
      return buffer;
    }

    final file = File(buffer.path);
    RandomAccessFile? handle;
    try {
      final length = await file.length();
      if (length > memoryLimitBytes) {
        throw AppError(
          category: ErrorCategory.runtime,
          code: 'runtime.file_too_large',
          message:
              'File ${buffer.name} berukuran $length byte, melebihi batas '
              'memori $memoryLimitBytes byte.',
          details: <String, Object?>{'size': length, 'limit': memoryLimitBytes},
        );
      }

      final bytes = Uint8List(length);
      handle = await file.open();
      var offset = 0;
      while (offset < length) {
        final end = math.min(offset + chunkBytes, length);
        final read = await handle.readInto(bytes, offset, end);
        if (read <= 0) {
          break;
        }
        offset += read;
      }
      if (offset != length) {
        throw AppError(
          category: ErrorCategory.storage,
          code: 'runtime.file_read_failed',
          message:
              'File ${buffer.name} hanya terbaca $offset dari $length byte.',
          details: <String, Object?>{
            'error': 'Pembacaan berhenti sebelum akhir file.',
          },
        );
      }
      return BytesBuffer(bytes);
    } on AppError {
      rethrow;
    } on FileSystemException catch (error) {
      throw AppError(
        category: ErrorCategory.storage,
        code: 'runtime.file_read_failed',
        message: 'Gagal membaca file ${buffer.name}: ${error.message}',
        details: <String, Object?>{'error': error.message},
      );
    } finally {
      await handle?.close();
    }
  }
}
