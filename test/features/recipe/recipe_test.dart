import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/support/fake_operations.dart';

const _recipeId = '4f1c2b7e-7d1a-4a3e-9f10-2c6b8f7a1d22';

Recipe _recipe({
  String id = _recipeId,
  String name = 'Base64 lalu Hex',
  List<RecipeStep>? steps,
  Buffer input = const TextBuffer('SGVsbG8='),
  Buffer? output,
  RecipeMeta? meta,
}) {
  return Recipe(
    id: id,
    name: name,
    steps:
        steps ??
        <RecipeStep>[
          RecipeStep(id: 'step-1', operationId: 'core.base64_decode'),
        ],
    input: input,
    output: output,
    meta: meta,
  );
}

OperationRegistry _registry() {
  final registry = OperationRegistry();
  registry.registerOperation(
    const ReverseTextOperation(),
    pluginId: 'com.test.pack',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  return registry;
}

void main() {
  group('Recipe JSON', () {
    test('round-trip dengan step, output, dan meta', () {
      final recipe = _recipe(
        output: const TextBuffer('Hello'),
        meta: RecipeMeta(
          createdAt: DateTime.utc(2026, 11, 11, 8),
          updatedAt: DateTime.utc(2026, 11, 11, 9),
          appVersion: '1.0.0',
        ),
      );

      final decoded = Recipe.fromJson(recipe.toJson());

      expect(decoded, recipe);
      expect(decoded.meta?.appVersion, '1.0.0');
      expect(decoded.steps.single, recipe.steps.single);
    });

    test('exporter dapat membuang output cache', () {
      final recipe = _recipe(output: const TextBuffer('Hello'));

      expect(
        recipe.toJson(includeOutput: false).containsKey('output'),
        isFalse,
      );
      expect(recipe.toJson().containsKey('output'), isTrue);
    });

    test('menolak schema lebih baru', () {
      final json = _recipe().toJson()..['schemaVersion'] = 2;

      expect(
        () => Recipe.fromJson(json),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'recipe.schema_unsupported',
          ),
        ),
      );
    });

    test('menolak field yang salah tipe', () {
      final base = _recipe().toJson();
      final invalid = <Map<String, Object?>>[
        <String, Object?>{...base, 'schemaVersion': '1'},
        <String, Object?>{...base, 'id': 1},
        <String, Object?>{...base, 'steps': 'satu'},
        <String, Object?>{
          ...base,
          'steps': <Object?>[
            <String, Object?>{'id': 'x'},
          ],
        },
        <String, Object?>{...base, 'input': <Object?>[]},
        <String, Object?>{...base, 'output': <Object?>[]},
        <String, Object?>{...base, 'meta': <Object?>[]},
        <String, Object?>{
          ...base,
          'meta': <String, Object?>{'appVersion': 1},
        },
        <String, Object?>{
          ...base,
          'meta': <String, Object?>{'createdAt': 'kemarin'},
        },
      ];

      for (final json in invalid) {
        expect(
          () => Recipe.fromJson(json),
          throwsA(isA<AppError>()),
          reason: '$json',
        );
      }
    });

    test('list steps dan args tidak dapat dimutasi', () {
      final recipe = _recipe();
      final step = recipe.steps.single;

      expect(() => recipe.steps.add(step), throwsA(isA<UnsupportedError>()));
      expect(() => step.args['x'] = 1, throwsA(isA<UnsupportedError>()));
    });

    test('copyWith dapat menghapus output', () {
      final recipe = _recipe(output: const TextBuffer('Hello'));
      final copy = recipe.copyWith(name: 'Baru', clearOutput: true);

      expect(copy.name, 'Baru');
      expect(copy.output, isNull);
      expect(recipe.output, isNotNull);
    });
  });

  group('Recipe validation', () {
    test('recipe valid tidak menghasilkan error', () {
      expect(_recipe().validate(), isEmpty);
    });

    test('menolak id, nama, dan step tidak valid', () {
      final invalid = <Recipe>[
        _recipe(id: 'bukan-uuid'),
        _recipe(name: '   '),
        _recipe(steps: <RecipeStep>[]),
        _recipe(
          steps: <RecipeStep>[RecipeStep(id: 'step-1', operationId: '')],
        ),
        _recipe(
          steps: <RecipeStep>[
            RecipeStep(id: 'step-1', operationId: 'a'),
            RecipeStep(id: 'step-1', operationId: 'b'),
          ],
        ),
      ];

      for (final recipe in invalid) {
        expect(recipe.validate(), isNotEmpty);
      }
    });

    test('memvalidasi args terhadap registry', () {
      final registry = _registry();

      final valid = _recipe(
        steps: <RecipeStep>[
          RecipeStep(
            id: 'step-1',
            operationId: 'test.reverse',
            args: <String, Object?>{'uppercase': true},
          ),
        ],
      );
      final invalid = _recipe(
        steps: <RecipeStep>[
          RecipeStep(
            id: 'step-1',
            operationId: 'test.reverse',
            args: <String, Object?>{'unknown': true},
          ),
        ],
      );

      expect(valid.validate(registry: registry), isEmpty);

      final errors = invalid.validate(registry: registry);
      expect(errors, hasLength(1));
      expect(errors.single.code, 'operation.param_unknown');
      expect(errors.single.stepId, 'step-1');
      expect(errors.single.pluginId, 'com.test.pack');
    });

    test('menolak input file saat allowFileInput=false', () {
      final recipe = _recipe(
        input: const FileBuffer(path: '/tmp/a.bin', name: 'a.bin'),
      );

      expect(recipe.validate(allowFileInput: false), hasLength(1));
      expect(
        recipe.validate(allowFileInput: false).single.code,
        'recipe.file_input_unsupported',
      );
    });
  });

  group('RecipeMeta', () {
    test('menyimpan tanggal sebagai UTC ISO-8601', () {
      final meta = RecipeMeta.fromJson(<String, Object?>{
        'createdAt': '2026-11-11T08:00:00+02:00',
        'appVersion': '1.0.0',
      });

      expect(meta.createdAt, DateTime.utc(2026, 11, 11, 6));
      expect(meta.toJson()['createdAt'], '2026-11-11T06:00:00.000Z');
      expect(RecipeMeta.fromJson(meta.toJson()), meta);
    });
  });
}
