import '../../core/engine/buffer.dart';
import '../../core/error/app_error.dart';
import '../../core/plugin/operation_param.dart';
import '../../core/plugin/operation_registry.dart';

const int currentRecipeSchemaVersion = 1;
const int maxRecipeSteps = 200;
const int maxRecipeNameLength = 120;

final class RecipeStep {
  RecipeStep({
    required this.id,
    required this.operationId,
    Map<String, Object?> args = const <String, Object?>{},
    this.enabled = true,
  }) : args = Map<String, Object?>.unmodifiable(args);

  final String id;
  final String operationId;
  final Map<String, Object?> args;
  final bool enabled;

  factory RecipeStep.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final operationId = json['operationId'];
    if (id is! String || operationId is! String) {
      throw _invalidField(
        'steps',
        'Step membutuhkan id dan operationId bertipe string.',
      );
    }

    final args = json['args'] ?? const <String, Object?>{};
    if (args is! Map<String, Object?>) {
      throw _invalidField('steps.args', 'Args step harus berupa objek.');
    }

    final enabled = json['enabled'] ?? true;
    if (enabled is! bool) {
      throw _invalidField(
        'steps.enabled',
        'Field enabled harus berupa boolean.',
      );
    }

    return RecipeStep(
      id: id,
      operationId: operationId,
      args: args,
      enabled: enabled,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'operationId': operationId,
      'args': args,
      'enabled': enabled,
    };
  }

  RecipeStep copyWith({
    String? id,
    String? operationId,
    Map<String, Object?>? args,
    bool? enabled,
  }) {
    return RecipeStep(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      args: args ?? this.args,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecipeStep &&
        other.id == id &&
        other.operationId == operationId &&
        other.enabled == enabled &&
        _mapEquals(other.args, args);
  }

  @override
  int get hashCode => Object.hash(id, operationId, enabled, args.length);
}

final class RecipeMeta {
  const RecipeMeta({this.createdAt, this.updatedAt, this.appVersion});

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? appVersion;

  factory RecipeMeta.fromJson(Map<String, Object?> json) {
    final appVersion = json['appVersion'];
    if (appVersion != null && appVersion is! String) {
      throw _invalidField('meta.appVersion', 'appVersion harus berupa string.');
    }
    return RecipeMeta(
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      appVersion: appVersion as String?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      if (appVersion != null) 'appVersion': appVersion,
    };
  }

  RecipeMeta copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    String? appVersion,
  }) {
    return RecipeMeta(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecipeMeta &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.appVersion == appVersion;
  }

  @override
  int get hashCode => Object.hash(createdAt, updatedAt, appVersion);
}

final class Recipe {
  Recipe({
    required this.id,
    required this.name,
    required List<RecipeStep> steps,
    required this.input,
    this.output,
    this.meta,
    this.schemaVersion = currentRecipeSchemaVersion,
  }) : steps = List<RecipeStep>.unmodifiable(steps);

  final int schemaVersion;
  final String id;
  final String name;
  final List<RecipeStep> steps;
  final Buffer input;

  /// Cache hasil terakhir. Tidak dipercaya saat impor dan tidak diekspor.
  final Buffer? output;
  final RecipeMeta? meta;

  factory Recipe.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int) {
      throw _invalidField(
        'schemaVersion',
        'schemaVersion wajib berupa integer.',
      );
    }
    if (schemaVersion != currentRecipeSchemaVersion) {
      throw AppError(
        category: ErrorCategory.validation,
        code: 'recipe.schema_unsupported',
        message: 'Versi schema recipe $schemaVersion tidak didukung.',
        details: <String, Object?>{
          'schemaVersion': schemaVersion,
          'supported': currentRecipeSchemaVersion,
        },
      );
    }

    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) {
      throw _invalidField(
        'id',
        'Recipe membutuhkan id dan name bertipe string.',
      );
    }

    final stepsJson = json['steps'];
    if (stepsJson is! List<Object?>) {
      throw _invalidField('steps', 'Field steps harus berupa array.');
    }
    final steps = <RecipeStep>[];
    for (var index = 0; index < stepsJson.length; index++) {
      final stepJson = stepsJson[index];
      if (stepJson is! Map<String, Object?>) {
        throw _invalidField('steps[$index]', 'Step harus berupa objek.');
      }
      steps.add(RecipeStep.fromJson(stepJson));
    }

    final inputJson = json['input'];
    if (inputJson is! Map<String, Object?>) {
      throw _invalidField('input', 'Field input wajib berupa objek Buffer.');
    }

    final outputJson = json['output'];
    Buffer? output;
    if (outputJson != null) {
      if (outputJson is! Map<String, Object?>) {
        throw _invalidField(
          'output',
          'Field output harus berupa objek Buffer.',
        );
      }
      output = Buffer.fromJson(outputJson);
    }

    final metaJson = json['meta'];
    RecipeMeta? meta;
    if (metaJson != null) {
      if (metaJson is! Map<String, Object?>) {
        throw _invalidField('meta', 'Field meta harus berupa objek.');
      }
      meta = RecipeMeta.fromJson(metaJson);
    }

    return Recipe(
      schemaVersion: schemaVersion,
      id: id,
      name: name,
      steps: steps,
      input: Buffer.fromJson(inputJson),
      output: output,
      meta: meta,
    );
  }

  Map<String, Object?> toJson({bool includeOutput = true}) {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'id': id,
      'name': name,
      'steps': steps.map((step) => step.toJson()).toList(),
      'input': input.toJson(),
      if (includeOutput && output != null) 'output': output!.toJson(),
      if (meta != null) 'meta': meta!.toJson(),
    };
  }

  /// Memvalidasi isi recipe. Error dikumpulkan agar UI bisa menampilkan
  /// beberapa masalah sekaligus.
  List<AppError> validate({
    OperationRegistry? registry,
    bool allowFileInput = true,
  }) {
    final errors = <AppError>[];

    if (schemaVersion != currentRecipeSchemaVersion) {
      errors.add(
        AppError(
          category: ErrorCategory.validation,
          code: 'recipe.schema_unsupported',
          message: 'Versi schema recipe $schemaVersion tidak didukung.',
          details: <String, Object?>{'schemaVersion': schemaVersion},
        ),
      );
    }

    if (!_uuidV4Pattern.hasMatch(id)) {
      errors.add(
        _invalidField('id', 'ID recipe harus UUID v4.', code: 'recipe.invalid'),
      );
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > maxRecipeNameLength) {
      errors.add(
        _invalidField(
          'name',
          'Nama recipe harus 1–$maxRecipeNameLength karakter.',
          code: 'recipe.invalid',
          details: <String, Object?>{'max': maxRecipeNameLength},
        ),
      );
    }

    if (steps.isEmpty || steps.length > maxRecipeSteps) {
      errors.add(
        _invalidField(
          'steps',
          'Recipe harus memiliki 1–$maxRecipeSteps step.',
          code: 'recipe.invalid',
          details: <String, Object?>{'max': maxRecipeSteps},
        ),
      );
    }

    final stepIds = <String>{};
    for (final step in steps) {
      if (step.id.trim().isEmpty) {
        errors.add(
          _invalidField(
            'steps.id',
            'ID step tidak boleh kosong.',
            code: 'recipe.invalid',
            stepId: step.id,
          ),
        );
      } else if (!stepIds.add(step.id)) {
        errors.add(
          _invalidField(
            'steps.id',
            'ID step duplikat: ${step.id}',
            code: 'recipe.invalid',
            stepId: step.id,
            details: <String, Object?>{'duplicate': true, 'stepId': step.id},
          ),
        );
      }

      if (step.operationId.trim().isEmpty) {
        errors.add(
          _invalidField(
            'steps.operationId',
            'operationId step tidak boleh kosong.',
            code: 'recipe.invalid',
            stepId: step.id,
          ),
        );
      }

      final entry = registry?.byId(step.operationId);
      if (entry != null) {
        final resolved = resolveOperationArgs(
          entry.descriptor.params,
          step.args,
        );
        if (!resolved.isSuccess) {
          errors.add(
            resolved.errorOrNull!.copyWith(
              stepId: step.id,
              pluginId: entry.descriptor.pluginId,
            ),
          );
        }
      }
    }

    if (!allowFileInput && input.kind == BufferKind.file) {
      errors.add(
        const AppError(
          category: ErrorCategory.validation,
          code: 'recipe.file_input_unsupported',
          message: 'Input file tidak didukung di file .brecipe v1.',
        ),
      );
    }

    return List<AppError>.unmodifiable(errors);
  }

  Recipe copyWith({
    int? schemaVersion,
    String? id,
    String? name,
    List<RecipeStep>? steps,
    Buffer? input,
    Buffer? output,
    bool clearOutput = false,
    RecipeMeta? meta,
  }) {
    return Recipe(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      id: id ?? this.id,
      name: name ?? this.name,
      steps: steps ?? this.steps,
      input: input ?? this.input,
      output: clearOutput ? null : output ?? this.output,
      meta: meta ?? this.meta,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Recipe &&
        other.schemaVersion == schemaVersion &&
        other.id == id &&
        other.name == name &&
        _listEquals(other.steps, steps) &&
        other.input == input &&
        other.output == output &&
        other.meta == meta;
  }

  @override
  int get hashCode {
    return Object.hash(
      schemaVersion,
      id,
      name,
      Object.hashAll(steps),
      input,
      output,
      meta,
    );
  }
}

final RegExp _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

AppError _invalidField(
  String field,
  String message, {
  String code = 'recipe.invalid',
  String? stepId,
  Map<String, Object?> details = const <String, Object?>{},
}) {
  return AppError(
    category: ErrorCategory.validation,
    code: code,
    message: message,
    stepId: stepId,
    details: <String, Object?>{'field': field, ...details},
  );
}

DateTime? _parseDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw _invalidField('meta', 'Tanggal meta harus berupa string ISO-8601.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw _invalidField('meta', 'Tanggal meta tidak valid: $value');
  }
  return parsed.toUtc();
}

bool _mapEquals(Map<String, Object?> first, Map<String, Object?> second) {
  if (first.length != second.length) {
    return false;
  }
  for (final key in first.keys) {
    if (!second.containsKey(key) || second[key] != first[key]) {
      return false;
    }
  }
  return true;
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
