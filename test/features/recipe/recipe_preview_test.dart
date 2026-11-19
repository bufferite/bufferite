import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/buffer_panel.dart';
import 'package:bufferite/features/operations/operation_providers.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/support/fake_operations.dart';

OperationRegistry _registry() {
  final registry = OperationRegistry();
  registry.registerOperation(
    const ReverseTextOperation(),
    pluginId: 'dev.bufferite.core',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  registry.registerOperation(
    const Base64DecodeOperation(),
    pluginId: 'dev.bufferite.core',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  return registry;
}

Widget _host({Recipe? recipe}) {
  return ProviderScope(
    overrides: [operationRegistryProvider.overrideWithValue(_registry())],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: RecipeEditorPage(recipe: recipe),
    ),
  );
}

String? _output(WidgetTester tester) {
  return tester.widget<BufferPanel>(find.byType(BufferPanel)).content;
}

Future<void> _openSteps(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Step'));
  await tester.pumpAndSettle();
}

Recipe _recipe(String input) {
  return Recipe(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Reverse',
    steps: <RecipeStep>[RecipeStep(id: 's1', operationId: 'test.reverse')],
    input: TextBuffer(input),
  );
}

void main() {
  testWidgets('preview live mengeksekusi step setelah debounce', (
    tester,
  ) async {
    await tester.pumpWidget(_host(recipe: _recipe('abc')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(_output(tester), 'cba');
  });

  testWidgets('preview diperbarui saat input berubah', (tester) async {
    await tester.pumpWidget(_host(recipe: _recipe('abc')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.enterText(find.byType(TextField).last, 'hello');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(_output(tester), 'olleh');
  });

  testWidgets('input kosong tanpa step tidak menampilkan output', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(_output(tester), isNull);
  });

  testWidgets('operasi tidak dikenal menampilkan badge unsupported', (
    tester,
  ) async {
    final recipe = Recipe(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Unknown',
      steps: <RecipeStep>[RecipeStep(id: 's1', operationId: 'core.tidak_ada')],
      input: const TextBuffer('abc'),
    );
    await tester.pumpWidget(_host(recipe: recipe));
    await tester.pump();
    await _openSteps(tester);

    expect(find.text('unsupported'), findsOneWidget);
  });

  testWidgets('error step ditampilkan pada kartu step', (tester) async {
    final recipe = Recipe(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Broken',
      steps: <RecipeStep>[
        RecipeStep(id: 's1', operationId: 'test.base64_decode'),
      ],
      input: const TextBuffer('%%%'),
    );
    await tester.pumpWidget(_host(recipe: recipe));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await _openSteps(tester);

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
