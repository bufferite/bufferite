import '../error/app_error.dart';
import 'plugin_manifest.dart';
import 'semantic_version.dart';

enum PluginSource {
  core,
  registry,
  sideload;

  static PluginSource parse(Object? value) {
    if (value is String) {
      for (final source in values) {
        if (source.name == value) {
          return source;
        }
      }
    }
    throw AppError(
      category: ErrorCategory.validation,
      code: 'plugin.source_invalid',
      message: 'Sumber plugin tidak dikenal: $value',
    );
  }
}

enum PluginStatus { active, disabled, unverified, incompatible }

/// Asal-usul paket registry untuk audit dan rollback (F16-T02/T04).
final class PluginProvenance {
  const PluginProvenance({
    required this.registryUrl,
    required this.keyId,
    required this.sha256,
    this.previousVersion,
    this.previousSource,
    this.previousVerified,
  });

  final String registryUrl;
  final String keyId;
  final String sha256;
  final String? previousVersion;
  final PluginSource? previousSource;
  final bool? previousVerified;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'registryUrl': registryUrl,
      'keyId': keyId,
      'sha256': sha256,
      if (previousVersion != null) 'previousVersion': previousVersion,
      if (previousSource != null) 'previousSource': previousSource!.name,
      if (previousVerified != null) 'previousVerified': previousVerified,
    };
  }

  factory PluginProvenance.fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'plugin.installed_invalid',
        message: 'Provenance plugin harus berupa objek.',
      );
    }
    final registryUrl = raw['registryUrl'];
    final keyId = raw['keyId'];
    final sha256 = raw['sha256'];
    final previousVersion = raw['previousVersion'];
    final previousSource = raw['previousSource'];
    final previousVerified = raw['previousVerified'];
    if (registryUrl is! String ||
        keyId is! String ||
        sha256 is! String ||
        (previousVersion != null && previousVersion is! String) ||
        (previousSource != null && previousSource is! String) ||
        (previousVerified != null && previousVerified is! bool)) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'plugin.installed_invalid',
        message: 'Field provenance plugin tidak valid.',
      );
    }
    return PluginProvenance(
      registryUrl: registryUrl,
      keyId: keyId,
      sha256: sha256,
      previousVersion: previousVersion as String?,
      previousSource: previousSource == null
          ? null
          : PluginSource.parse(previousSource),
      previousVerified: previousVerified as bool?,
    );
  }
}

/// Metadata plugin yang sudah terpasang.
final class InstalledPlugin {
  InstalledPlugin({
    required this.manifest,
    required this.source,
    required DateTime installedAt,
    this.enabled = true,
    this.verified = false,
    this.installPath,
    this.provenance,
  }) : installedAt = installedAt.toUtc();

  final PluginManifest manifest;
  final PluginSource source;
  final DateTime installedAt;
  final bool enabled;
  final bool verified;
  final String? installPath;
  final PluginProvenance? provenance;

  String get pluginId => manifest.pluginId;

  SemanticVersion get version => manifest.version;

  bool isCompatibleWith(SemanticVersion appVersion) {
    return manifest.isCompatibleWith(appVersion);
  }

  PluginStatus statusFor(SemanticVersion appVersion) {
    if (!enabled) {
      return PluginStatus.disabled;
    }
    if (!isCompatibleWith(appVersion)) {
      return PluginStatus.incompatible;
    }
    if (!verified) {
      return PluginStatus.unverified;
    }
    return PluginStatus.active;
  }

  InstalledPlugin copyWith({
    bool? enabled,
    bool? verified,
    String? installPath,
    PluginProvenance? provenance,
  }) {
    return InstalledPlugin(
      manifest: manifest,
      source: source,
      installedAt: installedAt,
      enabled: enabled ?? this.enabled,
      verified: verified ?? this.verified,
      installPath: installPath ?? this.installPath,
      provenance: provenance ?? this.provenance,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'manifest': manifest.toJson(),
      'source': source.name,
      'installedAt': installedAt.toIso8601String(),
      'enabled': enabled,
      'verified': verified,
      if (installPath != null) 'installPath': installPath,
      if (provenance != null) 'provenance': provenance!.toJson(),
    };
  }

  factory InstalledPlugin.fromJson(Map<String, Object?> json) {
    final manifestJson = json['manifest'];
    if (manifestJson is! Map<String, Object?>) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'plugin.installed_invalid',
        message: 'Metadata plugin harus memiliki objek manifest.',
      );
    }
    final installedAt = json['installedAt'];
    if (installedAt is! String) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'plugin.installed_invalid',
        message: 'installedAt plugin harus berupa ISO-8601 string.',
      );
    }
    final parsedDate = DateTime.tryParse(installedAt);
    if (parsedDate == null) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'plugin.installed_invalid',
        message: 'installedAt plugin bukan tanggal yang valid.',
      );
    }

    final enabled = json['enabled'] ?? true;
    final verified = json['verified'] ?? false;
    if (enabled is! bool || verified is! bool) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'plugin.installed_invalid',
        message: 'enabled dan verified plugin harus boolean.',
      );
    }
    final installPath = json['installPath'];
    if (installPath != null && installPath is! String) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'plugin.installed_invalid',
        message: 'installPath plugin harus string.',
      );
    }

    return InstalledPlugin(
      manifest: PluginManifest.fromJson(manifestJson),
      source: PluginSource.parse(json['source']),
      installedAt: parsedDate,
      enabled: enabled,
      verified: verified,
      installPath: installPath as String?,
      provenance: json['provenance'] == null
          ? null
          : PluginProvenance.fromJson(json['provenance']),
    );
  }
}
