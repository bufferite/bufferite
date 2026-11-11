import 'dart:convert';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import 'operation.dart';
import 'operation_param.dart';
import 'plugin_path.dart';
import 'plugin_permission.dart';
import 'semantic_version.dart';

/// Manifest `plugin.manifest.json` versi 1.
final class PluginManifest {
  PluginManifest({
    required this.pluginId,
    required this.name,
    required this.version,
    required this.minAppVersion,
    required this.tier,
    required this.entrypoint,
    required Set<PluginPermission> permissions,
    required List<ManifestOperation> operations,
    this.author,
    this.description,
    this.license,
    this.homepage,
    this.integritySha256,
    this.signature,
    this.manifestVersion = supportedManifestVersion,
  }) : permissions = Set<PluginPermission>.unmodifiable(permissions),
       operations = List<ManifestOperation>.unmodifiable(operations);

  static const int supportedManifestVersion = 1;

  final int manifestVersion;
  final String pluginId;
  final String name;
  final SemanticVersion version;
  final String? author;
  final String? description;
  final String? license;
  final String? homepage;
  final SemanticVersion minAppVersion;
  final RuntimeTier tier;

  /// Path relatif di dalam paket, memakai separator `/`.
  final String entrypoint;
  final Set<PluginPermission> permissions;
  final List<ManifestOperation> operations;

  /// SHA-256 entrypoint (hex 64 karakter) bila disediakan manifest.
  final String? integritySha256;
  final String? signature;

  factory PluginManifest.fromJson(Map<String, Object?> json) {
    final manifestVersion = json['manifestVersion'];
    if (manifestVersion is! int) {
      throw _invalid(
        'plugin.manifest_version_invalid',
        'manifestVersion wajib berupa integer.',
      );
    }
    if (manifestVersion != supportedManifestVersion) {
      throw AppError(
        category: ErrorCategory.unsupported,
        code: 'plugin.manifest_version_unsupported',
        message:
            'Manifest versi $manifestVersion tidak didukung '
            '(didukung: $supportedManifestVersion).',
        details: <String, Object?>{'manifestVersion': manifestVersion},
      );
    }

    final pluginId = _requiredString(json, 'pluginId');
    if (!RegExp(
      r'^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9_-]*)+$',
    ).hasMatch(pluginId)) {
      throw _invalid(
        'plugin.id_invalid',
        'pluginId harus reverse-DNS huruf kecil, mis. com.contoh.pack.',
        <String, Object?>{'pluginId': pluginId},
      );
    }

    final name = _requiredString(json, 'name').trim();
    if (name.isEmpty || name.length > 80) {
      throw _invalid('plugin.name_invalid', 'Nama plugin harus 1-80 karakter.');
    }

    final version = SemanticVersion.parse(_requiredString(json, 'version'));
    final minAppVersion = SemanticVersion.parse(
      _requiredString(json, 'minAppVersion'),
    );
    final tier = RuntimeTier.parse(json['tier']);
    final entrypoint = validateRelativePackagePath(
      _requiredString(json, 'entrypoint'),
    );
    _validateEntrypointForTier(entrypoint, tier);

    final operations = _parseOperations(json['operations']);
    final integrity = json['integrity'];
    if (integrity != null && integrity is! Map<String, Object?>) {
      throw _invalid(
        'plugin.integrity_invalid',
        'Field integrity harus berupa objek.',
      );
    }
    final integrityMap = integrity is Map<String, Object?>
        ? integrity
        : const <String, Object?>{};
    final sha256 = integrityMap['sha256'];
    if (sha256 != null &&
        (sha256 is! String || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha256))) {
      throw _invalid(
        'plugin.hash_invalid',
        'integrity.sha256 harus berupa hex SHA-256 64 karakter.',
      );
    }
    final signature = integrityMap['signature'];
    if (signature != null &&
        (signature is! String || signature.trim().isEmpty)) {
      throw _invalid(
        'plugin.signature_invalid',
        'integrity.signature harus berupa string tidak kosong.',
      );
    }

    return PluginManifest(
      manifestVersion: manifestVersion,
      pluginId: pluginId,
      name: name,
      version: version,
      author: _optionalString(json, 'author'),
      description: _optionalString(json, 'description'),
      license: _optionalString(json, 'license'),
      homepage: _optionalString(json, 'homepage'),
      minAppVersion: minAppVersion,
      tier: tier,
      entrypoint: entrypoint,
      permissions: PluginPermission.parseAll(json['permissions']),
      operations: operations,
      integritySha256: sha256 is String ? sha256.toLowerCase() : null,
      signature: signature is String ? signature.trim() : null,
    );
  }

  factory PluginManifest.fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, Object?>) {
        throw _invalid(
          'plugin.manifest_invalid',
          'Manifest harus berupa objek JSON.',
        );
      }
      return PluginManifest.fromJson(decoded);
    } on FormatException catch (error) {
      throw _invalid(
        'plugin.manifest_json_invalid',
        'Manifest bukan JSON valid: ${error.message}',
      );
    }
  }

  bool isCompatibleWith(SemanticVersion appVersion) {
    return appVersion.isAtLeast(minAppVersion);
  }

  List<OperationDescriptor> toOperationDescriptors({bool available = true}) {
    return List<OperationDescriptor>.unmodifiable(
      operations.map(
        (operation) => operation.toDescriptor(
          pluginId: pluginId,
          pluginVersion: version,
          tier: tier,
          available: available,
        ),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'manifestVersion': manifestVersion,
      'pluginId': pluginId,
      'name': name,
      'version': version.toString(),
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (license != null) 'license': license,
      if (homepage != null) 'homepage': homepage,
      'minAppVersion': minAppVersion.toString(),
      'tier': tier.name,
      'entrypoint': entrypoint,
      'permissions': permissions
          .map((permission) => permission.wireName)
          .toList(),
      'operations': operations.map((operation) => operation.toJson()).toList(),
      if (integritySha256 != null || signature != null)
        'integrity': <String, Object?>{
          if (integritySha256 != null) 'sha256': integritySha256,
          if (signature != null) 'signature': signature,
        },
    };
  }
}

final class ManifestOperation {
  ManifestOperation({
    required this.id,
    required this.name,
    required this.category,
    required List<OperationParam> params,
    required this.io,
    this.contractVersion = operationContractVersion,
  }) : params = List<OperationParam>.unmodifiable(params);

  final String id;
  final String name;
  final OperationCategory category;
  final List<OperationParam> params;
  final OperationIO io;
  final int contractVersion;

  factory ManifestOperation.fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id');
    if (!RegExp(r'^[a-z][a-z0-9._-]*$').hasMatch(id)) {
      throw _invalid(
        'plugin.operation_id_invalid',
        'ID operasi harus huruf kecil dan hanya memakai a-z, 0-9, titik, '
            'garis bawah, atau strip.',
        <String, Object?>{'operationId': id},
      );
    }
    final name = _requiredString(json, 'name').trim();
    if (name.isEmpty) {
      throw _invalid(
        'plugin.operation_name_invalid',
        'Nama operasi tidak boleh kosong.',
        <String, Object?>{'operationId': id},
      );
    }

    final contractVersion = json['contractVersion'] ?? operationContractVersion;
    if (contractVersion is! int || contractVersion < 1) {
      throw _invalid(
        'plugin.operation_contract_invalid',
        'contractVersion operasi harus integer positif.',
        <String, Object?>{'operationId': id},
      );
    }

    final paramsJson = json['params'] ?? const <Object?>[];
    if (paramsJson is! List) {
      throw _invalid(
        'plugin.operation_params_invalid',
        'params operasi harus berupa array.',
        <String, Object?>{'operationId': id},
      );
    }
    final params = <OperationParam>[];
    final keys = <String>{};
    for (final item in paramsJson) {
      if (item is! Map<String, Object?>) {
        throw _invalid(
          'plugin.operation_params_invalid',
          'Setiap parameter operasi harus berupa objek.',
          <String, Object?>{'operationId': id},
        );
      }
      final paramJson = Map<String, Object?>.from(item);
      paramJson.putIfAbsent('label', () => paramJson['key']);
      final param = OperationParam.fromJson(paramJson);
      if (!keys.add(param.key)) {
        throw _invalid(
          'plugin.operation_params_invalid',
          'Parameter duplikat: ${param.key}',
          <String, Object?>{'operationId': id},
        );
      }
      params.add(param);
    }

    return ManifestOperation(
      id: id,
      name: name,
      category: OperationCategory.parse(json['category']),
      params: params,
      io: OperationIO(
        input: BufferKind.parse(json['inputType']),
        output: BufferKind.parse(json['outputType']),
      ),
      contractVersion: contractVersion,
    );
  }

  OperationDescriptor toDescriptor({
    required String pluginId,
    required SemanticVersion pluginVersion,
    required RuntimeTier tier,
    bool available = true,
  }) {
    return OperationDescriptor(
      id: id,
      name: name,
      category: category,
      pluginId: pluginId,
      pluginVersion: pluginVersion.toString(),
      tier: tier,
      params: params,
      io: io,
      contractVersion: contractVersion,
      available: available,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'category': category.label,
      'params': params.map((param) => param.toJson()).toList(),
      'inputType': io.input.name,
      'outputType': io.output.name,
      if (contractVersion != operationContractVersion)
        'contractVersion': contractVersion,
    };
  }
}

List<ManifestOperation> _parseOperations(Object? value) {
  if (value is! List) {
    throw _invalid(
      'plugin.operations_invalid',
      'Manifest wajib memiliki array operations.',
    );
  }
  if (value.isEmpty) {
    throw _invalid(
      'plugin.operations_empty',
      'Manifest harus mendaftarkan minimal satu operasi.',
    );
  }

  final operations = <ManifestOperation>[];
  final ids = <String>{};
  for (final item in value) {
    if (item is! Map<String, Object?>) {
      throw _invalid(
        'plugin.operations_invalid',
        'Setiap operasi manifest harus berupa objek.',
      );
    }
    final operation = ManifestOperation.fromJson(item);
    if (!ids.add(operation.id)) {
      throw _invalid(
        'plugin.operation_duplicate',
        'ID operasi duplikat di manifest: ${operation.id}',
        <String, Object?>{'operationId': operation.id},
      );
    }
    operations.add(operation);
  }
  return operations;
}

String _requiredString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw _invalid(
      'plugin.field_invalid',
      'Field $field wajib berupa string tidak kosong.',
      <String, Object?>{'field': field},
    );
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw _invalid(
      'plugin.field_invalid',
      'Field $field harus berupa string.',
      <String, Object?>{'field': field},
    );
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

void _validateEntrypointForTier(String entrypoint, RuntimeTier tier) {
  final lower = entrypoint.toLowerCase();
  final valid = switch (tier) {
    RuntimeTier.lua => lower.endsWith('.lua'),
    RuntimeTier.wasm => lower.endsWith('.wasm'),
    RuntimeTier.dsl =>
      lower.endsWith('.json') ||
          lower.endsWith('.yaml') ||
          lower.endsWith('.yml'),
  };
  if (!valid) {
    throw _invalid(
      'plugin.entrypoint_tier_mismatch',
      'Entrypoint $entrypoint tidak cocok dengan tier ${tier.name}.',
      <String, Object?>{'entrypoint': entrypoint, 'tier': tier.name},
    );
  }
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
