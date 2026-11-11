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

/// Metadata plugin yang sudah terpasang.
final class InstalledPlugin {
  InstalledPlugin({
    required this.manifest,
    required this.source,
    required DateTime installedAt,
    this.enabled = true,
    this.verified = false,
    this.installPath,
  }) : installedAt = installedAt.toUtc();

  final PluginManifest manifest;
  final PluginSource source;
  final DateTime installedAt;
  final bool enabled;
  final bool verified;
  final String? installPath;

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
  }) {
    return InstalledPlugin(
      manifest: manifest,
      source: source,
      installedAt: installedAt,
      enabled: enabled ?? this.enabled,
      verified: verified ?? this.verified,
      installPath: installPath ?? this.installPath,
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
    );
  }
}
