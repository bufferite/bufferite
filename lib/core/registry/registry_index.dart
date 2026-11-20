import 'dart:convert';

import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/plugin/semantic_version.dart';

/// Batas ukuran `registry.json` sesuai `REGISTRY.md` §4.2.
const int registryMaxIndexBytes = 5 * 1024 * 1024;

/// Jumlah maksimum rilis dalam satu indeks.
const int registryMaxEntries = 2000;

/// Jumlah maksimum host yang diizinkan.
const int registryMaxAllowedHosts = 8;

/// Error terstruktur untuk format registry.
final class RegistryFormatException implements Exception {
  const RegistryFormatException(
    this.code,
    this.message, [
    this.details = const <String, Object?>{},
  ]);

  final String code;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => '$code: $message';
}

enum RegistryEntryStatus {
  active,
  deprecated,
  yanked,
  revoked;

  /// Boleh dipilih untuk instalasi/downgrade; `yanked`/`revoked` ditolak.
  bool get selectable => this == active || this == deprecated;

  static RegistryEntryStatus parse(Object? value) {
    for (final status in values) {
      if (status.name == value) {
        return status;
      }
    }
    throw RegistryFormatException(
      'registry.schema',
      'status tidak dikenal: $value',
      <String, Object?>{'status': value},
    );
  }
}

/// Satu rilis plugin di `registry.json` v1.
final class RegistryEntry {
  RegistryEntry({
    required this.pluginId,
    required this.version,
    required this.name,
    required this.summary,
    required this.tier,
    required this.minAppVersion,
    required Set<PluginPermission> permissions,
    required this.sizeBytes,
    required this.sha256,
    required this.downloadUrl,
    required this.publishedAt,
    required this.status,
    this.description,
    this.author,
    this.license,
    this.homepage,
    this.signatureUrl,
    List<String> tags = const <String>[],
  }) : permissions = Set<PluginPermission>.unmodifiable(permissions),
       tags = List<String>.unmodifiable(tags);

  final String pluginId;
  final SemanticVersion version;
  final String name;
  final String summary;
  final String? description;
  final String? author;
  final String? license;
  final String? homepage;
  final RuntimeTier tier;
  final SemanticVersion minAppVersion;
  final Set<PluginPermission> permissions;
  final int sizeBytes;
  final String sha256;
  final String downloadUrl;
  final String? signatureUrl;
  final DateTime publishedAt;
  final RegistryEntryStatus status;
  final List<String> tags;

  /// `signatureUrl` efektif; default `downloadUrl + ".sig"` sesuai §4.1.
  String get effectiveSignatureUrl => signatureUrl ?? '$downloadUrl.sig';

  factory RegistryEntry.fromJson(Object? raw) {
    final json = _object(raw, 'plugins[]');
    final pluginId = _string(json, 'pluginId');
    if (!_pluginIdPattern.hasMatch(pluginId)) {
      throw RegistryFormatException(
        'registry.schema',
        'pluginId tidak valid: $pluginId',
        <String, Object?>{'pluginId': pluginId},
      );
    }

    final version = _semver(json, 'version');
    final name = _boundedString(json, 'name', 80);
    final summary = _boundedString(json, 'summary', 200);
    final tier = _tier(json['tier']);
    final minAppVersion = _semver(json, 'minAppVersion');
    final permissions = _permissions(json['permissions']);
    final sizeBytes = _sizeBytes(json['sizeBytes']);
    final sha256 = _sha256(json['sha256']);
    final downloadUrl = _urlString(json, 'downloadUrl');
    final signatureUrl = json['signatureUrl'] == null
        ? null
        : _urlString(json, 'signatureUrl');
    final publishedAt = _utcDate(json, 'publishedAt');
    final status = RegistryEntryStatus.parse(json['status']);
    final description = _optionalBounded(json, 'description', 4000);
    final author = _optionalBounded(json, 'author', 120);
    final license = _optionalBounded(json, 'license', 64);
    final homepage = _optionalBounded(json, 'homepage', 512);
    final tags = _tags(json['tags']);

    return RegistryEntry(
      pluginId: pluginId,
      version: version,
      name: name,
      summary: summary,
      description: description,
      author: author,
      license: license,
      homepage: homepage,
      tier: tier,
      minAppVersion: minAppVersion,
      permissions: permissions,
      sizeBytes: sizeBytes,
      sha256: sha256,
      downloadUrl: downloadUrl,
      signatureUrl: signatureUrl,
      publishedAt: publishedAt,
      status: status,
      tags: tags,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'pluginId': pluginId,
      'version': version.toString(),
      'name': name,
      'summary': summary,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
      if (license != null) 'license': license,
      if (homepage != null) 'homepage': homepage,
      'tier': tier.name,
      'minAppVersion': minAppVersion.toString(),
      'permissions': permissions.map((item) => item.wireName).toList()..sort(),
      'sizeBytes': sizeBytes,
      'sha256': sha256,
      'downloadUrl': downloadUrl,
      if (signatureUrl != null) 'signatureUrl': signatureUrl,
      'publishedAt': _formatDate(publishedAt),
      'status': status.name,
      if (tags.isNotEmpty) 'tags': tags,
    };
  }

  void validateUrls(Uri registryBase) {
    final resolved = _resolveUrl(downloadUrl, registryBase);
    if (resolved.scheme != 'https' || resolved.host.isEmpty) {
      throw RegistryFormatException(
        'registry.schema',
        'downloadUrl harus HTTPS setelah resolusi: $downloadUrl',
      );
    }
    final signature = _resolveUrl(effectiveSignatureUrl, registryBase);
    if (signature.scheme != 'https' || signature.host.isEmpty) {
      throw RegistryFormatException(
        'registry.schema',
        'signatureUrl harus HTTPS setelah resolusi: $effectiveSignatureUrl',
      );
    }
  }
}

/// Model `registry.json` v1.
final class RegistryIndex {
  RegistryIndex({
    required this.sequence,
    required this.generatedAt,
    required List<String> allowedHosts,
    required List<RegistryEntry> plugins,
  }) : allowedHosts = List<String>.unmodifiable(allowedHosts),
       plugins = List<RegistryEntry>.unmodifiable(plugins);

  static const int supportedVersion = 1;

  final int sequence;
  final DateTime generatedAt;
  final List<String> allowedHosts;
  final List<RegistryEntry> plugins;

  factory RegistryIndex.parse(String source) {
    return RegistryIndex.fromBytes(utf8.encode(source));
  }

  factory RegistryIndex.fromBytes(List<int> bytes) {
    if (bytes.length > registryMaxIndexBytes) {
      throw RegistryFormatException(
        'registry.too_large',
        'registry.json melebihi $registryMaxIndexBytes byte.',
        <String, Object?>{'size': bytes.length},
      );
    }
    final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException catch (error) {
      throw RegistryFormatException(
        'registry.json_invalid',
        'registry.json bukan UTF-8 valid: ${error.message}',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw RegistryFormatException(
        'registry.json_invalid',
        'registry.json bukan JSON valid: ${error.message}',
      );
    }
    return RegistryIndex.fromJson(decoded);
  }

  factory RegistryIndex.fromJson(Object? raw) {
    final json = _object(raw, 'registry.json');
    final registryVersion = json['registryVersion'];
    if (registryVersion is! int) {
      throw const RegistryFormatException(
        'registry.schema',
        'registryVersion wajib berupa integer.',
      );
    }
    if (registryVersion != supportedVersion) {
      throw RegistryFormatException(
        registryVersion > supportedVersion
            ? 'registry.app_too_old'
            : 'registry.schema',
        'registryVersion $registryVersion tidak didukung '
        '(didukung: $supportedVersion).',
        <String, Object?>{'registryVersion': registryVersion},
      );
    }

    final sequence = json['sequence'];
    if (sequence is! int || sequence < 1) {
      throw const RegistryFormatException(
        'registry.schema',
        'sequence harus integer positif.',
      );
    }
    final generatedAt = _utcDate(json, 'generatedAt');
    final allowedHosts = _allowedHosts(json['allowedHosts']);

    final rawPlugins = json['plugins'];
    if (rawPlugins is! List<Object?>) {
      throw const RegistryFormatException(
        'registry.schema',
        'plugins harus berupa array.',
      );
    }
    if (rawPlugins.length > registryMaxEntries) {
      throw RegistryFormatException(
        'registry.schema',
        'plugins melebihi $registryMaxEntries rilis.',
        <String, Object?>{'entries': rawPlugins.length},
      );
    }

    final plugins = <RegistryEntry>[];
    final seen = <String>{};
    for (final rawEntry in rawPlugins) {
      final entry = RegistryEntry.fromJson(rawEntry);
      final key = '${entry.pluginId}@${entry.version}';
      if (!seen.add(key)) {
        throw RegistryFormatException(
          'registry.schema',
          'Entri duplikat untuk $key.',
          <String, Object?>{
            'pluginId': entry.pluginId,
            'version': '$entry.version',
          },
        );
      }
      plugins.add(entry);
    }

    return RegistryIndex(
      sequence: sequence,
      generatedAt: generatedAt,
      allowedHosts: allowedHosts,
      plugins: plugins,
    );
  }

  /// Validasi URL setiap entri terhadap `registryBase` (URL `registry.json`).
  void validateUrls(Uri registryBase) {
    if (registryBase.scheme != 'https' || registryBase.host.isEmpty) {
      throw const RegistryFormatException(
        'registry.schema',
        'URL registry harus HTTPS.',
      );
    }
    if (!allowedHosts.contains(registryBase.host.toLowerCase())) {
      throw RegistryFormatException(
        'registry.schema',
        'Host registry ${registryBase.host} tidak ada di allowedHosts.',
      );
    }
    for (final entry in plugins) {
      entry.validateUrls(registryBase);
      final host = _resolveUrl(entry.downloadUrl, registryBase).host;
      if (!allowedHosts.contains(host.toLowerCase())) {
        throw RegistryFormatException(
          'registry.schema',
          'Host paket $host tidak ada di allowedHosts.',
          <String, Object?>{'pluginId': entry.pluginId},
        );
      }
      final signatureHost = _resolveUrl(
        entry.effectiveSignatureUrl,
        registryBase,
      ).host;
      if (!allowedHosts.contains(signatureHost.toLowerCase())) {
        throw RegistryFormatException(
          'registry.schema',
          'Host signature $signatureHost tidak ada di allowedHosts.',
          <String, Object?>{'pluginId': entry.pluginId},
        );
      }
    }
  }

  /// JSON kanonik: entri diurutkan pluginId lalu versi, field stabil.
  Map<String, Object?> toJson() {
    final ordered = List<RegistryEntry>.of(plugins)
      ..sort((a, b) {
        final id = a.pluginId.compareTo(b.pluginId);
        return id != 0 ? id : a.version.compareTo(b.version);
      });
    return <String, Object?>{
      'registryVersion': supportedVersion,
      'sequence': sequence,
      'generatedAt': _formatDate(generatedAt),
      'allowedHosts': List<String>.of(allowedHosts)..sort(),
      'plugins': ordered.map((entry) => entry.toJson()).toList(),
    };
  }

  /// Encode deterministik (indentasi 2 spasi + newline akhir).
  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';
}

final RegExp _pluginIdPattern = RegExp(
  r'^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9_-]*)+$',
);
final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final RegExp _hostPattern = RegExp(
  r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)(?:\.(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?))*$',
);

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw RegistryFormatException(
      'registry.schema',
      '$field harus berupa objek.',
    );
  }
  return value;
}

String _string(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw RegistryFormatException(
      'registry.schema',
      '$field wajib berupa string tidak kosong.',
      <String, Object?>{'field': field},
    );
  }
  return value;
}

String _boundedString(Map<String, Object?> json, String field, int max) {
  final value = _string(json, field);
  if (value.length > max) {
    throw RegistryFormatException(
      'registry.schema',
      '$field melebihi $max karakter.',
      <String, Object?>{'field': field},
    );
  }
  return value;
}

String? _optionalBounded(Map<String, Object?> json, String field, int max) {
  final value = json[field];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw RegistryFormatException(
      'registry.schema',
      '$field harus berupa string.',
      <String, Object?>{'field': field},
    );
  }
  if (value.length > max) {
    throw RegistryFormatException(
      'registry.schema',
      '$field melebihi $max karakter.',
      <String, Object?>{'field': field},
    );
  }
  return value.isEmpty ? null : value;
}

SemanticVersion _semver(Map<String, Object?> json, String field) {
  final value = _string(json, field);
  try {
    return SemanticVersion.parse(value);
  } on Object catch (error) {
    throw RegistryFormatException(
      'registry.schema',
      '$field bukan semver valid: $error',
      <String, Object?>{'field': field, 'value': value},
    );
  }
}

RuntimeTier _tier(Object? value) {
  for (final tier in RuntimeTier.values) {
    if (tier.name == value) {
      return tier;
    }
  }
  throw RegistryFormatException(
    'registry.schema',
    'tier tidak dikenal: $value',
    <String, Object?>{'tier': value},
  );
}

Set<PluginPermission> _permissions(Object? value) {
  if (value is! List<Object?> || value.isEmpty) {
    throw const RegistryFormatException(
      'registry.schema',
      'permissions harus berupa array tidak kosong.',
    );
  }
  final result = <PluginPermission>{};
  for (final item in value) {
    if (item is! String) {
      throw const RegistryFormatException(
        'registry.schema',
        'permissions harus berisi string.',
      );
    }
    final permission = _permission(item);
    if (permission == null) {
      throw RegistryFormatException(
        'registry.schema',
        'Izin tidak dikenal: $item',
        <String, Object?>{'permission': item},
      );
    }
    if (!result.add(permission)) {
      throw RegistryFormatException(
        'registry.schema',
        'Izin duplikat: $item',
        <String, Object?>{'permission': item},
      );
    }
  }
  return result;
}

PluginPermission? _permission(String value) {
  for (final permission in PluginPermission.values) {
    if (permission.wireName == value) {
      return permission;
    }
  }
  return null;
}

int _sizeBytes(Object? value) {
  if (value is! int || value < 1 || value > 32 * 1024 * 1024) {
    throw const RegistryFormatException(
      'registry.schema',
      'sizeBytes harus 1..33554432.',
    );
  }
  return value;
}

String _sha256(Object? value) {
  if (value is! String || !_sha256Pattern.hasMatch(value)) {
    throw const RegistryFormatException(
      'registry.schema',
      'sha256 harus hex lowercase 64 karakter.',
    );
  }
  return value;
}

String _urlString(Map<String, Object?> json, String field) {
  final value = _string(json, field);
  if (value.length > 2048) {
    throw RegistryFormatException(
      'registry.schema',
      '$field melebihi 2048 karakter.',
    );
  }
  if (value.contains('\\') || value.contains('\u0000')) {
    throw RegistryFormatException(
      'registry.schema',
      '$field memuat karakter terlarang.',
    );
  }
  final uri = Uri.tryParse(value);
  if (uri == null) {
    throw RegistryFormatException('registry.schema', '$field bukan URL valid.');
  }
  if (uri.hasScheme && uri.scheme != 'https') {
    throw RegistryFormatException(
      'registry.schema',
      '$field absolut harus HTTPS.',
    );
  }
  if (!uri.hasScheme &&
      (value.startsWith('//') || uri.pathSegments.contains('..'))) {
    throw RegistryFormatException(
      'registry.schema',
      '$field relatif tidak aman.',
    );
  }
  return value;
}

List<String> _allowedHosts(Object? value) {
  if (value is! List<Object?> ||
      value.isEmpty ||
      value.length > registryMaxAllowedHosts) {
    throw const RegistryFormatException(
      'registry.schema',
      'allowedHosts harus 1..8 hostname.',
    );
  }
  final hosts = <String>[];
  for (final item in value) {
    if (item is! String || !_hostPattern.hasMatch(item)) {
      throw RegistryFormatException(
        'registry.schema',
        'Hostname tidak valid: $item',
        <String, Object?>{'host': item},
      );
    }
    if (hosts.contains(item)) {
      throw RegistryFormatException(
        'registry.schema',
        'Hostname duplikat: $item',
      );
    }
    hosts.add(item);
  }
  return hosts;
}

List<String> _tags(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<Object?> || value.length > 8) {
    throw const RegistryFormatException(
      'registry.schema',
      'tags harus array maksimal 8 item.',
    );
  }
  final tags = <String>[];
  for (final item in value) {
    if (item is! String || item.isEmpty || item.length > 32) {
      throw const RegistryFormatException(
        'registry.schema',
        'Setiap tag harus 1..32 karakter.',
      );
    }
    if (tags.contains(item)) {
      throw RegistryFormatException('registry.schema', 'Tag duplikat: $item');
    }
    tags.add(item);
  }
  return tags..sort();
}

DateTime _utcDate(Map<String, Object?> json, String field) {
  final value = _string(json, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw RegistryFormatException(
      'registry.schema',
      '$field harus ISO-8601 UTC.',
      <String, Object?>{'field': field, 'value': value},
    );
  }
  return parsed;
}

String _formatDate(DateTime value) {
  final utc = value.toUtc();
  final text = utc.toIso8601String();
  return text.endsWith('.000Z')
      ? '${text.substring(0, text.length - 5)}Z'
      : text;
}

Uri _resolveUrl(String value, Uri base) {
  final uri = Uri.parse(value);
  return uri.hasScheme ? uri : base.resolveUri(uri);
}
