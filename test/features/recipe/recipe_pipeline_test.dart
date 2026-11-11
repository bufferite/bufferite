import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/engine/pipeline.dart';
import 'package:bufferite/core/engine/pipeline_executor.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/support/fake_operations.dart';

const _recipeId = '4f1c2b7e-7d1a-4a3e-9f10-2c6b8f7a1d22';

void main() {
  test('recipe berjalan end-to-end dari registry ke output', () async {
    final registry = OperationRegistry();
    registry.registerOperation(
      const Base64DecodeOperation(),
      pluginId: 'core.test',
      pluginVersion: '1.0.0',
      tier: RuntimeTier.lua,
    );
    registry.registerOperation(
      const ReverseTextOperation(),
      pluginId: 'com.test.pack',
      pluginVersion: '1.0.0',
      tier: RuntimeTier.dsl,
    );
    final recipe = Recipe(
      id: _recipeId,
      name: 'Base64 lalu reverse',
      steps: <RecipeStep>[
        RecipeStep(id: 'step-1', operationId: 'test.base64_decode'),
        RecipeStep(id: 'step-2', operationId: 'test.reverse'),
      ],
      input: const TextBuffer('SGVsbG8='),
    );
    final executor = PipelineExecutor(registry: registry);

    final result = await executor.execute(
      steps: recipe.toPipelineSteps(),
      input: recipe.input,
    );

    expect(recipe.validate(registry: registry), isEmpty);
    expect(result.isSuccess, isTrue);
    expect(result.output, const TextBuffer('olleH'));
    expect(
      result.events.where(
        (event) => event.type == PipelineEventType.stepSucceeded,
      ),
      hasLength(2),
    );
  });
}
