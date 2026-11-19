import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../error/app_error.dart';
import 'plugin_manifest.dart';
import 'plugin_path.dart';

/// Batas keamanan paket `.berp` sebelum dan sesudah dekompresi.
final class PluginPackageLimits {
  const PluginPackageLimits({
    this.maxPackageBytes = 32 * 1024 * 1024,
    this.maxEntries = 512,
    this.maxEntryBytes = 16 * 1024 * 1024,
    this.maxTotalBytes = 64 * 1024 * 1024,
    this.maxManifestBytes = 512 * 1024,
  });

  static const PluginPackageLimits defaults = PluginPackageLimits();

  final int maxPackageBytes;
  final int maxEntries;
  final int maxEntryBytes;
  final int maxTotalBytes;
  final int maxManifestBytes;
}

/// Paket plugin tervalidasi: manifest + isi file yang sudah dicek batasnya.
final class PluginPackage {
  PluginPackage._({
    required this.manifest,
    required Map<String, Uint8List> files,
  }) : _files = Map<String, Uint8List>.unmodifiable(files);

  static const String manifestPath = 'plugin.manifest.json';

  final PluginManifest manifest;
  final Map<String, Uint8List> _files;

  factory PluginPackage.decode(
    Uint8List bytes, {
    PluginPackageLimits limits = PluginPackageLimits.defaults,
  }) {
    if (bytes.isEmpty) {
      throw _packageError('plugin.package_empty', 'Paket .berp kosong.');
    }
    if (bytes.length > limits.maxPackageBytes) {
      throw _packageError(
        'plugin.package_too_large',
        'Ukuran paket melebihi batas ${limits.maxPackageBytes} byte.',
        <String, Object?>{
          'size': bytes.length,
          'limit': limits.maxPackageBytes,
        },
      );
    }

    // `ZipDecoder` membaca isi symlink saat decode (sebelum batas entri dapat
    // diperiksa) dan membangun satu objek per entri. Pindai central directory
    // lebih dulu tanpa menyentuh isi entri agar zip bomb dan jumlah entri
    // raksasa ditolak sebelum alokasi/dekompresi.
    _scanArchive(bytes, limits);

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(
        bytes,
        verify: true,
        throwOnError: true,
      );
    } on Object catch (error) {
      throw _packageError(
        'plugin.package_invalid',
        'Paket .berp bukan zip yang valid.',
        <String, Object?>{'error': error.toString()},
      );
    }

    if (archive.files.length > limits.maxEntries) {
      throw _packageError(
        'plugin.package_too_many_entries',
        'Paket memiliki terlalu banyak entri.',
        <String, Object?>{
          'entries': archive.files.length,
          'limit': limits.maxEntries,
        },
      );
    }

    final entries = <ArchiveFile>[];
    final names = <String>{};
    ArchiveFile? manifestEntry;
    var declaredTotal = 0;

    for (final entry in archive.files) {
      if (entry.isSymbolicLink) {
        throw _packageError(
          'plugin.package_symlink',
          'Paket tidak boleh memuat symbolic link: ${entry.name}',
          <String, Object?>{'path': entry.name},
        );
      }
      final isDirectory = !entry.isFile;
      final rawName = entry.name;
      final pathToValidate = isDirectory && rawName.endsWith('/')
          ? rawName.substring(0, rawName.length - 1)
          : rawName;
      final name = validateRelativePackagePath(
        pathToValidate,
        code: 'plugin.package_path_invalid',
        field: 'path',
        category: ErrorCategory.plugin,
      );
      if (isDirectory) {
        continue;
      }
      if (entry.name != name) {
        throw _packageError(
          'plugin.package_path_invalid',
          'Nama file tidak boleh berakhir dengan separator: ${entry.name}',
          <String, Object?>{'path': entry.name},
        );
      }
      if (!names.add(name.toLowerCase())) {
        throw _packageError(
          'plugin.package_duplicate_entry',
          'Paket memuat entri duplikat: $name',
          <String, Object?>{'path': name},
        );
      }
      if (entry.size < 0 || entry.size > limits.maxEntryBytes) {
        throw _packageError(
          'plugin.package_entry_too_large',
          'Entri $name melebihi batas ukuran.',
          <String, Object?>{'path': name, 'size': entry.size},
        );
      }
      declaredTotal += entry.size;
      if (declaredTotal > limits.maxTotalBytes) {
        throw _packageError(
          'plugin.package_too_large',
          'Total isi paket melebihi batas ${limits.maxTotalBytes} byte.',
          <String, Object?>{
            'total': declaredTotal,
            'limit': limits.maxTotalBytes,
          },
        );
      }

      if (name == manifestPath) {
        manifestEntry = entry;
      }
      entries.add(entry);
    }

    if (manifestEntry == null) {
      throw _packageError(
        'plugin.manifest_missing',
        'Paket tidak memiliki $manifestPath di root.',
      );
    }
    if (manifestEntry.size > limits.maxManifestBytes) {
      throw _packageError(
        'plugin.manifest_too_large',
        'Manifest melebihi batas ${limits.maxManifestBytes} byte.',
      );
    }

    final PluginManifest manifest;
    try {
      final manifestBytes = _readEntry(manifestEntry, limits);
      manifest = PluginManifest.fromJsonString(utf8.decode(manifestBytes));
    } on AppError {
      rethrow;
    } on FormatException catch (error) {
      throw _packageError(
        'plugin.manifest_encoding_invalid',
        'Manifest bukan UTF-8 valid: ${error.message}',
      );
    }

    final files = <String, Uint8List>{};
    var actualTotal = 0;
    for (final entry in entries) {
      final data = _readEntry(entry, limits);
      actualTotal += data.length;
      if (actualTotal > limits.maxTotalBytes) {
        throw _packageError(
          'plugin.package_too_large',
          'Total isi paket melebihi batas ${limits.maxTotalBytes} byte.',
          <String, Object?>{
            'total': actualTotal,
            'limit': limits.maxTotalBytes,
          },
        );
      }
      files[entry.name] = data;
    }

    if (!files.containsKey(manifest.entrypoint)) {
      throw _packageError(
        'plugin.entrypoint_missing',
        'Entrypoint ${manifest.entrypoint} tidak ada di dalam paket.',
        <String, Object?>{'entrypoint': manifest.entrypoint},
      );
    }

    return PluginPackage._(manifest: manifest, files: files);
  }

  List<String> get fileNames =>
      List<String>.unmodifiable(_files.keys.toList()..sort());

  Uint8List entrypointBytes() {
    final data = _files[manifest.entrypoint];
    if (data == null) {
      throw _packageError(
        'plugin.entrypoint_missing',
        'Entrypoint ${manifest.entrypoint} tidak ada di dalam paket.',
      );
    }
    return Uint8List.fromList(data);
  }

  Uint8List? read(String path) {
    final data = _files[path];
    return data == null ? null : Uint8List.fromList(data);
  }

  Map<String, Uint8List> filesSnapshot() {
    return <String, Uint8List>{
      for (final entry in _files.entries)
        entry.key: Uint8List.fromList(entry.value),
    };
  }
}

/// Memindai central directory zip tanpa membaca isi entri.
///
/// `ZipDecoder.decodeBytes` membaca target symlink secara eager dan membuat
/// objek untuk setiap entri sebelum [PluginPackage.decode] dapat memeriksa
/// batas. Pemindaian ini menolak symlink, jumlah entri, serta ukuran entri
/// deklarasi lebih dulu sehingga paket berbahaya tidak pernah didekompresi.
void _scanArchive(Uint8List bytes, PluginPackageLimits limits) {
  final directory = ZipDirectory();
  var entries = 0;
  var declaredTotal = 0;
  try {
    for (final header in directory.headers(
      InputMemoryStream(bytes),
      verify: true,
      files: false,
    )) {
      entries++;
      if (entries > limits.maxEntries) {
        throw _packageError(
          'plugin.package_too_many_entries',
          'Paket memiliki terlalu banyak entri.',
          <String, Object?>{'entries': entries, 'limit': limits.maxEntries},
        );
      }

      final name = header.filename;
      final mode = header.externalFileAttributes;
      final entryMode = mode >> 16;
      final madeByUnix = header.versionMadeBy >> 8 == 3;
      if (madeByUnix && entryMode & 0xf000 == 0xa000) {
        throw _packageError(
          'plugin.package_symlink',
          'Paket tidak boleh memuat symbolic link: $name',
          <String, Object?>{'path': name},
        );
      }

      // Sama dengan klasifikasi direktori di `ZipDecoder`.
      final isDirectory =
          name.endsWith('/') ||
          name.endsWith('\\') ||
          (header.versionMadeBy >> 8 == 0 && mode & 0x10 != 0) ||
          (madeByUnix && entryMode & 0xf000 == 0x4000);
      if (isDirectory) {
        continue;
      }

      final size = header.uncompressedSize;
      if (size < 0 || size > limits.maxEntryBytes) {
        throw _packageError(
          'plugin.package_entry_too_large',
          'Entri $name melebihi batas ukuran.',
          <String, Object?>{'path': name, 'size': size},
        );
      }
      declaredTotal += size;
      if (declaredTotal > limits.maxTotalBytes) {
        throw _packageError(
          'plugin.package_too_large',
          'Total isi paket melebihi batas ${limits.maxTotalBytes} byte.',
          <String, Object?>{
            'total': declaredTotal,
            'limit': limits.maxTotalBytes,
          },
        );
      }
    }
  } on AppError {
    rethrow;
  } on Object catch (error) {
    throw _packageError(
      'plugin.package_invalid',
      'Paket .berp bukan zip yang valid.',
      <String, Object?>{'error': error.toString()},
    );
  }
}

Uint8List _readEntry(ArchiveFile entry, PluginPackageLimits limits) {
  try {
    final data = Uint8List.fromList(entry.content);
    if (data.length > limits.maxEntryBytes) {
      throw _packageError(
        'plugin.package_entry_too_large',
        'Entri ${entry.name} melebihi batas ukuran.',
        <String, Object?>{'path': entry.name, 'size': data.length},
      );
    }
    return data;
  } on AppError {
    rethrow;
  } on Object catch (error) {
    throw _packageError(
      'plugin.package_invalid',
      'Gagal membaca entri ${entry.name}.',
      <String, Object?>{'path': entry.name, 'error': error.toString()},
    );
  }
}

AppError _packageError(
  String code,
  String message, [
  Map<String, Object?> details = const <String, Object?>{},
]) {
  return AppError(
    category: ErrorCategory.plugin,
    code: code,
    message: message,
    details: details,
  );
}
