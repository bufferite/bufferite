import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_id.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _recipe() {
  return Recipe(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Base64 Decode',
    steps: <RecipeStep>[
      RecipeStep(id: 'step-1', operationId: 'core.reverse'),
      RecipeStep(id: 'step-2', operationId: 'core.reverse'),
    ],
    input: const TextBuffer('halo'),
  );
}

void main() {
  test('generateRecipeId menghasilkan UUID v4 valid dan unik', () {
    final ids = <String>{for (var i = 0; i < 50; i++) generateRecipeId()};
    expect(ids, hasLength(50));
    for (final id in ids) {
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
        reason: id,
      );
      expect(_recipe().copyWith(id: id).validate(), isEmpty);
    }
  });

  test('duplicateRecipe memberi ID/nama baru dan step ID unik', () {
    final source = _recipe();
    final copy = duplicateRecipe(
      source,
      now: DateTime.utc(2026, 1, 2),
      id: '22222222-2222-4222-9222-222222222222',
    );

    expect(copy.id, '22222222-2222-4222-9222-222222222222');
    expect(copy.name, 'Base64 Decode (copy)');
    expect(copy.meta?.createdAt, DateTime.utc(2026, 1, 2));
    expect(copy.steps, hasLength(2));
    expect(copy.steps.map((step) => step.id).toSet(), hasLength(2));
    expect(copy.output, isNull);
    expect(copy.validate(), isEmpty);
  });

  test('nama copy dipotong agar tetap <= 120 karakter', () {
    final longName = 'a' * maxRecipeNameLength;
    final copy = duplicateRecipe(
      _recipe().copyWith(name: longName),
      id: '22222222-2222-4222-9222-222222222222',
    );

    expect(copy.name.length, lessThanOrEqualTo(maxRecipeNameLength));
    expect(copy.name.endsWith(' (copy)'), isTrue);
  });
}
