import 'dart:convert';

import '../../core/engine/buffer.dart';
import '../../core/error/app_error.dart';
import '../../core/error/result.dart';
import '../../core/plugin/operation_registry.dart';
import 'recipe.dart';

typedef RecipeMigration =
    Map<String, Object?> Function(Map<String, Object?> json);

/// Codec file `.brecipe` (JSON) dengan batas ukuran, migrasi schema, dan
/// validasi sebelum recipe dipakai.
final class RecipeCodec {
  RecipeCodec({
    this.maxBytes = defaultMaxBytes,
    Map<int, RecipeMigration> migrations = const <int, RecipeMigration>{},
  }) : migrations = Map<int, RecipeMigration>.unmodifiable(migrations);

  static const int defaultMaxBytes = 5 * 1024 * 1024;
  static const int _maxMigrationSteps = 64;

  final int maxBytes;

  /// Key = versi asal, value = fungsi yang menaikkan versi tepat satu langkah.
  final Map<int, RecipeMigration> migrations;

  Result<Recipe> decode(
    String source, {
    OperationRegistry? registry,
    bool allowFileInput = false,
  }) {
    if (utf8.encode(source).length > maxBytes) {
      return Err<Recipe>(
        _error(
          'recipe.too_large',
          'Ukuran recipe melebihi batas $maxBytes byte.',
          <String, Object?>{'maxBytes': maxBytes},
        ),
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      return Err<Recipe>(
        _error(
          'recipe.invalid_json',
          'Recipe bukan JSON yang valid.',
          <String, Object?>{'error': error.message},
        ),
      );
    }

    if (decoded is! Map<String, Object?>) {
      return Err<Recipe>(
        _error(
          'recipe.invalid_json',
          'Recipe harus berupa objek JSON.',
          <String, Object?>{'variant': 'not_object'},
        ),
      );
    }

    var json = Map<String, Object?>.from(decoded);
    final rawVersion = json['schemaVersion'];
    if (rawVersion is! int) {
      return Err<Recipe>(
        _error(
          'recipe.schema_missing',
          'Recipe wajib memiliki schemaVersion bertipe integer.',
        ),
      );
    }
    if (rawVersion > currentRecipeSchemaVersion) {
      return Err<Recipe>(_unsupportedVersion(rawVersion));
    }

    var version = rawVersion;
    var migrationCount = 0;
    while (version < currentRecipeSchemaVersion) {
      final migration = migrations[version];
      if (migration == null) {
        return Err<Recipe>(
          _error(
            'recipe.migration_missing',
            'Tidak ada migrasi dari schemaVersion $version.',
            <String, Object?>{'fromVersion': version},
          ),
        );
      }

      try {
        json = Map<String, Object?>.from(migration(json));
      } on AppError catch (error) {
        return Err<Recipe>(error);
      }

      final nextVersion = json['schemaVersion'];
      if (nextVersion is! int || nextVersion != version + 1) {
        return Err<Recipe>(
          _error(
            'recipe.migration_invalid',
            'Migrasi schema $version harus menaikkan versi ke ${version + 1}.',
            <String, Object?>{
              'fromVersion': version,
              'toVersion': version + 1,
            },
          ),
        );
      }

      version = nextVersion;
      migrationCount++;
      if (migrationCount > _maxMigrationSteps) {
        return Err<Recipe>(
          _error(
            'recipe.migration_loop',
            'Migrasi recipe melebihi batas langkah.',
          ),
        );
      }
    }

    try {
      final recipe = Recipe.fromJson(json);
      if (!allowFileInput && recipe.input.kind == BufferKind.file) {
        return Err<Recipe>(
          _error(
            'recipe.file_input_unsupported',
            'Input file tidak didukung di file .brecipe v1.',
          ),
        );
      }

      final errors = recipe.validate(
        registry: registry,
        allowFileInput: allowFileInput,
      );
      if (errors.isNotEmpty) {
        return Err<Recipe>(errors.first);
      }
      return Ok<Recipe>(recipe);
    } on AppError catch (error) {
      return Err<Recipe>(error);
    }
  }

  Result<String> encode(Recipe recipe, {bool pretty = true}) {
    final errors = recipe.validate(allowFileInput: false);
    if (errors.isNotEmpty) {
      return Err<String>(errors.first);
    }

    try {
      final json = recipe.toJson(includeOutput: false);
      final source = pretty
          ? const JsonEncoder.withIndent('  ').convert(json)
          : jsonEncode(json);
      if (utf8.encode(source).length > maxBytes) {
        return Err<String>(
          _error(
            'recipe.too_large',
            'Ukuran recipe melebihi batas $maxBytes byte.',
            <String, Object?>{'maxBytes': maxBytes},
          ),
        );
      }
      return Ok<String>(source);
    } on JsonUnsupportedObjectError catch (error) {
      return Err<String>(
        _error(
          'recipe.encode_failed',
          'Recipe memuat nilai yang tidak dapat diserialisasi.',
          <String, Object?>{'error': error.toString()},
        ),
      );
    }
  }

  AppError _unsupportedVersion(int version) {
    return _error(
      'recipe.schema_unsupported',
      'Versi schema recipe $version tidak didukung.',
      <String, Object?>{
        'schemaVersion': version,
        'supported': currentRecipeSchemaVersion,
      },
    );
  }
}

AppError _error(
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
