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

  static const int _fixedTime = 315532800; // 1980-01-01 UTC, detik.

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
      entries[relative] = entity.readAsBytesSync();
    }

    final names = entries.keys.toList()..sort();
    final archive = Archive();
    for (final name in names) {
      final bytes = entries[name]!;
      archive.addFile(
        ArchiveFile(name, bytes.length, bytes)..lastModTime = _fixedTime,
      );
    }

    final encoded = Uint8List.fromList(ZipEncoder().encode(archive));
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

/// Utilitas kecil untuk tool: membaca manifest JSON bila ada.
Map<String, Object?> readManifest(Directory source) {
  final file = File('${source.path}/manifest/core.manifest.json');
  if (!file.existsSync()) {
    return const <String, Object?>{};
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}
