import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/plugin/plugin_package.dart';
import 'package:bufferite/core/registry/registry_index.dart';
import 'package:bufferite/core/registry/registry_signature.dart';
import 'package:crypto/crypto.dart';

const int _maxSourceBytes = 1024 * 1024;
const int _maxPackageBytes = 32 * 1024 * 1024;

/// Metadata satu paket di file source build index.
final class RegistryBuildEntrySource {
  const RegistryBuildEntrySource({
    required this.path,
    required this.summary,
    required this.publishedAt,
    this.pluginId,
    this.version,
    this.description,
    this.author,
    this.license,
    this.homepage,
    this.downloadUrl,
    this.signatureUrl,
    this.status = RegistryEntryStatus.active,
    this.tags = const <String>[],
  });

  final String path;
  final String summary;
  final DateTime publishedAt;
  final String? pluginId;
  final String? version;
  final String? description;
  final String? author;
  final String? license;
  final String? homepage;
  final String? downloadUrl;
  final String? signatureUrl;
  final RegistryEntryStatus status;
  final List<String> tags;

  factory RegistryBuildEntrySource.fromJson(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw RegistryFormatException(
        'registry.entry_invalid',
        'packages[$index] harus berupa objek.',
      );
    }
    final path = raw['path'];
    if (path is! String || path.isEmpty) {
      throw RegistryFormatException(
        'registry.entry_invalid',
        'packages[$index].path wajib diisi.',
      );
    }
    final summary = raw['summary'];
    if (summary is! String || summary.isEmpty || summary.length > 200) {
      throw RegistryFormatException(
        'registry.entry_invalid',
        'packages[$index].summary harus 1..200 karakter.',
      );
    }
    final publishedAt = _date(
      raw['publishedAt'],
      'packages[$index].publishedAt',
    );
    final status = raw['status'] == null
        ? RegistryEntryStatus.active
        : RegistryEntryStatus.parse(raw['status']);
    final tags = _stringList(raw['tags'], 'packages[$index].tags');
    return RegistryBuildEntrySource(
      path: path,
      summary: summary,
      publishedAt: publishedAt,
      pluginId: _optionalString(raw['pluginId'], 'packages[$index].pluginId'),
      version: _optionalString(raw['version'], 'packages[$index].version'),
      description: _optionalString(
        raw['description'],
        'packages[$index].description',
      ),
      author: _optionalString(raw['author'], 'packages[$index].author'),
      license: _optionalString(raw['license'], 'packages[$index].license'),
      homepage: _optionalString(raw['homepage'], 'packages[$index].homepage'),
      downloadUrl: _optionalString(
        raw['downloadUrl'],
        'packages[$index].downloadUrl',
      ),
      signatureUrl: _optionalString(
        raw['signatureUrl'],
        'packages[$index].signatureUrl',
      ),
      status: status,
      tags: tags,
    );
  }
}

/// File `registry-source.json` untuk `build-index`.
final class RegistryBuildSource {
  const RegistryBuildSource({
    required this.baseUrl,
    required this.allowedHosts,
    required this.packages,
    this.generatedAt,
  });

  final Uri baseUrl;
  final List<String> allowedHosts;
  final List<RegistryBuildEntrySource> packages;
  final DateTime? generatedAt;

  factory RegistryBuildSource.fromBytes(List<int> bytes) {
    if (bytes.length > _maxSourceBytes) {
      throw const RegistryFormatException(
        'registry.too_large',
        'registry-source.json melebihi 1 MiB.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (error) {
      throw RegistryFormatException(
        'registry.json_invalid',
        'registry-source.json bukan JSON valid: $error',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const RegistryFormatException(
        'registry.json_invalid',
        'registry-source.json harus berupa objek.',
      );
    }
    final baseUrl = _optionalString(decoded['baseUrl'], 'baseUrl');
    if (baseUrl == null) {
      throw const RegistryFormatException(
        'registry.schema',
        'baseUrl wajib diisi.',
      );
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const RegistryFormatException(
        'registry.schema',
        'baseUrl harus URL HTTPS.',
      );
    }
    final allowedHosts = _stringList(decoded['allowedHosts'], 'allowedHosts');
    if (allowedHosts.isEmpty || allowedHosts.length > registryMaxAllowedHosts) {
      throw const RegistryFormatException(
        'registry.schema',
        'allowedHosts harus 1..8 hostname.',
      );
    }
    final rawPackages = decoded['packages'];
    if (rawPackages is! List<Object?>) {
      throw const RegistryFormatException(
        'registry.schema',
        'packages harus berupa array.',
      );
    }
    if (rawPackages.length > registryMaxEntries) {
      throw const RegistryFormatException(
        'registry.schema',
        'packages melebihi 2000 rilis.',
      );
    }
    final packages = <RegistryBuildEntrySource>[];
    for (var index = 0; index < rawPackages.length; index++) {
      packages.add(
        RegistryBuildEntrySource.fromJson(rawPackages[index], index),
      );
    }
    return RegistryBuildSource(
      baseUrl: uri,
      allowedHosts: allowedHosts,
      packages: packages,
      generatedAt: decoded['generatedAt'] == null
          ? null
          : _date(decoded['generatedAt'], 'generatedAt'),
    );
  }
}

final class RegistryBuildResult {
  const RegistryBuildResult({
    required this.index,
    required this.content,
    required this.entries,
  });

  final RegistryIndex index;
  final String content;
  final List<RegistryBuiltEntry> entries;
}

final class RegistryBuiltEntry {
  const RegistryBuiltEntry({
    required this.entry,
    required this.packageFile,
    required this.signatureFile,
    required this.sha256,
  });

  final RegistryEntry entry;
  final File packageFile;
  final File signatureFile;
  final String sha256;
}

/// Bangun `registry.json` deterministik dari paket + metadata source.
final class RegistryIndexBuilder {
  const RegistryIndexBuilder();

  Future<RegistryBuildResult> build({
    required File sourceFile,
    File? baseIndexFile,
    int? sequence,
    DateTime? generatedAt,
    RegistryTrustStore? trustStore,
  }) async {
    final source = RegistryBuildSource.fromBytes(sourceFile.readAsBytesSync());
    final baseIndex = baseIndexFile != null && baseIndexFile.existsSync()
        ? RegistryIndex.fromBytes(baseIndexFile.readAsBytesSync())
        : null;

    final built = <RegistryBuiltEntry>[];
    final keys = <String>{};
    final sourceDir = sourceFile.parent;

    for (final item in source.packages) {
      final packageFile = _resolvePackageFile(sourceDir, item.path);
      final bytes = _readPackage(packageFile);
      final pluginId = item.pluginId;
      final version = item.version;

      final PluginPackage package;
      try {
        package = PluginPackage.decode(bytes);
      } on Object catch (error) {
        throw RegistryFormatException(
          'registry.entry_invalid',
          'Paket ${item.path} tidak valid: $error',
          <String, Object?>{'path': item.path},
        );
      }
      final manifest = package.manifest;
      if (pluginId != null && pluginId != manifest.pluginId) {
        throw RegistryFormatException(
          'registry.entry_invalid',
          'pluginId source tidak cocok dengan manifest ${manifest.pluginId}.',
        );
      }
      if (version != null && version != manifest.version.toString()) {
        throw RegistryFormatException(
          'registry.entry_invalid',
          'version source tidak cocok dengan manifest '
              '${manifest.version}.',
        );
      }

      final key = '${manifest.pluginId}@${manifest.version}';
      if (!keys.add(key)) {
        throw RegistryFormatException(
          'registry.entry_invalid',
          'Paket duplikat untuk $key.',
        );
      }

      final digest = sha256.convert(bytes).toString();
      final signatureFile = File('${packageFile.path}.sig');
      if (!signatureFile.existsSync()) {
        throw RegistryFormatException(
          'registry.entry_invalid',
          'Signature paket tidak ditemukan: ${signatureFile.path}',
        );
      }
      final signatureBytes = signatureFile.readAsBytesSync();
      if (signatureBytes.length > registryMaxSignatureBytes) {
        throw RegistryFormatException(
          'registry.signature_invalid',
          'Signature ${signatureFile.path} melebihi 4 KiB.',
        );
      }
      if (trustStore != null) {
        final signature = RegistrySignature.fromBytes(signatureBytes);
        await verifyRegistrySignature(
          signature: signature,
          message: registryPackageMessage(
            pluginId: manifest.pluginId,
            version: manifest.version.toString(),
            bytes: bytes,
          ),
          trustStore: trustStore,
          usage: 'package',
        );
      }

      final downloadUrl = item.downloadUrl ?? _defaultDownloadUrl(item.path);
      final entry = RegistryEntry(
        pluginId: manifest.pluginId,
        version: manifest.version,
        name: manifest.name,
        summary: item.summary,
        description: item.description ?? manifest.description,
        author: item.author ?? manifest.author,
        license: item.license ?? manifest.license,
        homepage: item.homepage ?? manifest.homepage,
        tier: manifest.tier,
        minAppVersion: manifest.minAppVersion,
        permissions: manifest.permissions,
        sizeBytes: bytes.length,
        sha256: digest,
        downloadUrl: downloadUrl,
        signatureUrl: item.signatureUrl,
        publishedAt: item.publishedAt,
        status: item.status,
        tags: item.tags,
      );
      built.add(
        RegistryBuiltEntry(
          entry: entry,
          packageFile: packageFile,
          signatureFile: signatureFile,
          sha256: digest,
        ),
      );
    }

    final resolvedSequence = sequence ?? (baseIndex?.sequence ?? 0) + 1;
    if (resolvedSequence < 1) {
      throw const RegistryFormatException(
        'registry.schema',
        'sequence harus positif.',
      );
    }
    if (baseIndex != null && resolvedSequence <= baseIndex.sequence) {
      throw RegistryFormatException(
        'registry.schema',
        'sequence baru ($resolvedSequence) harus lebih besar dari '
            'indeks lama (${baseIndex.sequence}).',
      );
    }
    final resolvedGeneratedAt =
        generatedAt ??
        source.generatedAt ??
        _latestPublishedAt(built) ??
        baseIndex?.generatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final index = RegistryIndex.fromJson(
      RegistryIndex(
        sequence: resolvedSequence,
        generatedAt: resolvedGeneratedAt,
        allowedHosts: source.allowedHosts,
        plugins: built.map((item) => item.entry).toList(),
      ).toJson(),
    );
    index.validateUrls(source.baseUrl);

    return RegistryBuildResult(
      index: index,
      content: index.encode(),
      entries: List<RegistryBuiltEntry>.unmodifiable(built),
    );
  }
}

/// Tulis file lewat file sementara di direktori yang sama.
void writeFileAtomically(File target, String content) {
  target.parent.createSync(recursive: true);
  final temporary = File('${target.path}.tmp');
  temporary.writeAsStringSync(content, flush: true);
  try {
    temporary.renameSync(target.path);
  } on FileSystemException {
    // Windows tidak mengganti file yang sudah ada lewat rename.
    if (target.existsSync()) {
      target.deleteSync();
    }
    temporary.renameSync(target.path);
  }
}

File _resolvePackageFile(Directory sourceDir, String relative) {
  final normalized = relative.replaceAll('\\', '/');
  if (normalized.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
      normalized.split('/').contains('..')) {
    throw RegistryFormatException(
      'registry.entry_invalid',
      'path paket tidak aman: $relative',
    );
  }
  return File(
    '${sourceDir.path}${Platform.pathSeparator}'
    '${normalized.replaceAll('/', Platform.pathSeparator)}',
  );
}

Uint8List _readPackage(File file) {
  if (!file.existsSync()) {
    throw RegistryFormatException(
      'registry.entry_invalid',
      'Paket tidak ditemukan: ${file.path}',
    );
  }
  final length = file.lengthSync();
  if (length < 1 || length > _maxPackageBytes) {
    throw RegistryFormatException(
      'registry.entry_invalid',
      'Ukuran paket ${file.path} di luar batas.',
    );
  }
  return file.readAsBytesSync();
}

String _defaultDownloadUrl(String path) {
  final normalized = path.replaceAll('\\', '/');
  if (!normalized.startsWith('packages/')) {
    throw const RegistryFormatException(
      'registry.entry_invalid',
      'downloadUrl wajib diisi bila path tidak berada di packages/.',
    );
  }
  return normalized;
}

DateTime? _latestPublishedAt(List<RegistryBuiltEntry> entries) {
  DateTime? latest;
  for (final item in entries) {
    if (latest == null || item.entry.publishedAt.isAfter(latest)) {
      latest = item.entry.publishedAt;
    }
  }
  return latest;
}

String? _optionalString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String || value.isEmpty) {
    throw RegistryFormatException(
      'registry.schema',
      '$field harus berupa string tidak kosong.',
    );
  }
  return value;
}

List<String> _stringList(Object? value, String field) {
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<Object?> || value.any((item) => item is! String)) {
    throw RegistryFormatException(
      'registry.schema',
      '$field harus berupa array string.',
    );
  }
  return value.cast<String>();
}

DateTime _date(Object? value, String field) {
  if (value is! String) {
    throw RegistryFormatException(
      'registry.schema',
      '$field wajib berupa string ISO-8601 UTC.',
    );
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw RegistryFormatException(
      'registry.schema',
      '$field harus ISO-8601 UTC.',
    );
  }
  return parsed;
}
