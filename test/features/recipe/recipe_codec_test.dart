import 'dart:convert';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/support/fake_operations.dart';

const _recipeId = '4f1c2b7e-7d1a-4a3e-9f10-2c6b8f7a1d22';

Recipe _recipe({
  String id = _recipeId,
  Buffer input = const TextBuffer('SGVsbG8='),
  Buffer? output,
  List<RecipeStep>? steps,
}) {
  return Recipe(
    id: id,
    name: 'Base64 lalu Hex',
    steps:
        steps ??
        <RecipeStep>[
          RecipeStep(id: 'step-1', operationId: 'core.base64_decode'),
        ],
    input: input,
    output: output,
  );
}

void main() {
  group('RecipeCodec encode/decode', () {
    test('round-trip dan membuang output cache', () {
      final codec = RecipeCodec();
      final recipe = _recipe(output: const TextBuffer('Hello'));

      final encoded = codec.encode(recipe);
      expect(encoded.isSuccess, isTrue);
      expect(encoded.valueOrNull, isNot(contains('"output"')));

      final decoded = codec.decode(encoded.valueOrNull!);
      expect(decoded.isSuccess, isTrue);
      expect(decoded.valueOrNull!.output, isNull);
      expect(decoded.valueOrNull!.id, recipe.id);
      expect(
        decoded.valueOrNull!.steps.single.operationId,
        'core.base64_decode',
      );
    });

    test('mode compact tidak memakai newline', () {
      final codec = RecipeCodec();
      final encoded = codec.encode(_recipe(), pretty: false);

      expect(encoded.valueOrNull, isNot(contains('\n')));
    });

    test('menolak JSON invalid dan bukan objek', () {
      final codec = RecipeCodec();

      expect(codec.decode('{').errorOrNull?.code, 'recipe.invalid_json');
      expect(codec.decode('[]').errorOrNull?.code, 'recipe.invalid_json');
      expect(
        codec.decode('{"id":"x"}').errorOrNull?.code,
        'recipe.schema_missing',
      );
    });

    test('menolak schema lebih baru', () {
      final codec = RecipeCodec();
      final json = _recipe().toJson()..['schemaVersion'] = 2;

      final result = codec.decode(jsonEncode(json));

      expect(result.errorOrNull?.code, 'recipe.schema_unsupported');
    });

    test('menolak input file di .brecipe v1', () {
      final codec = RecipeCodec();
      final recipe = _recipe(
        input: const FileBuffer(path: '/tmp/a.bin', name: 'a.bin'),
      );

      final result = codec.decode(jsonEncode(recipe.toJson()));

      expect(result.errorOrNull?.code, 'recipe.file_input_unsupported');
    });

    test('menghormati batas ukuran saat encode dan decode', () {
      final codec = RecipeCodec(maxBytes: 100);
      final padding = List<String>.filled(101, 'x').join();

      expect(codec.encode(_recipe()).errorOrNull?.code, 'recipe.too_large');
      expect(
        codec.decode('{"pad":"$padding"}').errorOrNull?.code,
        'recipe.too_large',
      );
    });

    test('menolak recipe tidak valid saat encode', () {
      final codec = RecipeCodec();

      expect(
        codec.encode(_recipe(id: 'bukan-uuid')).errorOrNull?.code,
        'recipe.invalid',
      );
      expect(
        codec
            .encode(
              _recipe(
                input: const FileBuffer(path: '/tmp/a.bin', name: 'a.bin'),
              ),
            )
            .errorOrNull
            ?.code,
        'recipe.file_input_unsupported',
      );
    });

    test('memvalidasi args dengan registry', () {
      final codec = RecipeCodec();
      final registry = OperationRegistry();
      registry.registerOperation(
        const ReverseTextOperation(),
        pluginId: 'com.test.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.dsl,
      );
      final recipe = _recipe(
        steps: <RecipeStep>[
          RecipeStep(
            id: 'step-1',
            operationId: 'test.reverse',
            args: <String, Object?>{'unknown': true},
          ),
        ],
      );

      final result = codec.decode(
        jsonEncode(recipe.toJson()),
        registry: registry,
      );

      expect(result.errorOrNull?.code, 'operation.param_unknown');
      expect(result.errorOrNull?.stepId, 'step-1');
    });
  });

  group('RecipeCodec migration', () {
    test('menjalankan migrasi berantai ke schema saat ini', () {
      final codec = RecipeCodec(
        migrations: <int, RecipeMigration>{
          0: (json) => <String, Object?>{...json, 'schemaVersion': 1},
        },
      );
      final json = _recipe().toJson()..['schemaVersion'] = 0;

      final result = codec.decode(jsonEncode(json));

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.schemaVersion, currentRecipeSchemaVersion);
    });

    test('menolak migrasi yang tidak tersedia', () {
      final codec = RecipeCodec();
      final json = _recipe().toJson()..['schemaVersion'] = 0;

      final result = codec.decode(jsonEncode(json));

      expect(result.errorOrNull?.code, 'recipe.migration_missing');
    });

    test('menolak migrasi yang tidak menaikkan versi', () {
      final codec = RecipeCodec(
        migrations: <int, RecipeMigration>{
          0: (json) => <String, Object?>{...json},
        },
      );
      final json = _recipe().toJson()..['schemaVersion'] = 0;

      final result = codec.decode(jsonEncode(json));

      expect(result.errorOrNull?.code, 'recipe.migration_invalid');
    });

    test('meneruskan AppError dari migrasi', () {
      final codec = RecipeCodec(
        migrations: <int, RecipeMigration>{
          0: (json) => throw const AppError(
            category: ErrorCategory.validation,
            code: 'recipe.migration_failed',
            message: 'Gagal migrasi.',
          ),
        },
      );
      final json = _recipe().toJson()..['schemaVersion'] = 0;

      final result = codec.decode(jsonEncode(json));

      expect(result.errorOrNull?.code, 'recipe.migration_failed');
    });
  });
}
