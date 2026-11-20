import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Hasil build paket `.berp`.
final class CorePackageBuildResult {
  const CorePackageBuildResult({
    required this.archiveBytes,
    required this.sha256,
    required this.files,
  });

  final Uint8List archiveBytes;
  final String sha256;
  final List<String> files;
}

/// Membungkus folder source menjadi `.berp` deterministik.
///
/// Nama file diurutkan, timestamp dinormalkan, dan kompresi tetap sehingga
/// hash stabil antar build.
final class CorePackageBuilder {
  const CorePackageBuilder();

  static final DateTime _fixedModified = DateTime.utc(1980);

  CorePackageBuildResult build(Directory source) {
    final entries = <String, Uint8List>{};
    for (final entity in source.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final relative = entity.path
          .substring(source.path.length + 1)
          .replaceAll('\\', '/');
      if (relative == 'README.md' || relative.endsWith('.sha256')) {
        continue;
      }
      // Manifest paket harus berada di root arsip (PLUGINS.md).
      final archiveName = relative == 'manifest/core.manifest.json'
          ? 'plugin.manifest.json'
          : relative;
      entries[archiveName] = entity.readAsBytesSync();
    }

    final names = entries.keys.toList()..sort();
    final archive = Archive();
    for (final name in names) {
      final bytes = entries[name]!;
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    // Timestamp DOS dihitung dari waktu lokal oleh ZipEncoder. Normalisasi
    // setelah encoding supaya hash tidak berubah antar zona waktu.
    final encoded = _normalizeDosTimestamps(
      Uint8List.fromList(
        ZipEncoder().encode(archive, modified: _fixedModified),
      ),
    );
    final digest = sha256.convert(encoded).toString();
    return CorePackageBuildResult(
      archiveBytes: encoded,
      sha256: digest,
      files: names,
    );
  }

  /// Menulis `core.berp` + `core.berp.sha256` dan mengembalikan hash.
  CorePackageBuildResult buildTo(
    Directory source,
    Directory output, {
    String fileName = 'core.berp',
  }) {
    final result = build(source);
    output.createSync(recursive: true);
    File('${output.path}/$fileName').writeAsBytesSync(result.archiveBytes);
    File(
      '${output.path}/$fileName.sha256',
    ).writeAsStringSync('${result.sha256}\n');
    return result;
  }
}

const int _zipLocalHeaderSignature = 0x04034b50;
const int _zipCentralHeaderSignature = 0x02014b50;
const int _zipEndSignature = 0x06054b50;

/// Menulis timestamp DOS 1980-01-01 00:00:00 ke semua header ZIP.
Uint8List _normalizeDosTimestamps(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final eocd = _findEndOfCentralDirectory(data);
  final count = data.getUint16(eocd + 10, Endian.little);
  var offset = data.getUint32(eocd + 16, Endian.little);

  for (var i = 0; i < count; i++) {
    if (data.getUint32(offset, Endian.little) != _zipCentralHeaderSignature) {
      throw const FormatException('Central directory ZIP tidak valid.');
    }
    final local = data.getUint32(offset + 42, Endian.little);
    if (data.getUint32(local, Endian.little) != _zipLocalHeaderSignature) {
      throw const FormatException('Local header ZIP tidak valid.');
    }

    data.setUint16(offset + 12, 0, Endian.little);
    data.setUint16(offset + 14, 0x21, Endian.little);
    data.setUint16(local + 10, 0, Endian.little);
    data.setUint16(local + 12, 0x21, Endian.little);

    offset +=
        46 +
        data.getUint16(offset + 28, Endian.little) +
        data.getUint16(offset + 30, Endian.little) +
        data.getUint16(offset + 32, Endian.little);
  }

  return bytes;
}

int _findEndOfCentralDirectory(ByteData data) {
  final last = data.lengthInBytes - 22;
  final first = last - 0xffff < 0 ? 0 : last - 0xffff;
  for (var offset = last; offset >= first; offset--) {
    if (data.getUint32(offset, Endian.little) == _zipEndSignature) {
      return offset;
    }
  }
  throw const FormatException('ZIP tanpa end of central directory.');
}

/// Utilitas kecil untuk tool: membaca manifest JSON bila ada.
Map<String, Object?> readManifest(Directory source) {
  final file = File('${source.path}/manifest/core.manifest.json');
  if (!file.existsSync()) {
    return const <String, Object?>{};
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}
