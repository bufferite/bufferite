import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/step_card.dart';
import 'package:bufferite/features/operations/operation_providers.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/support/fake_operations.dart';

Recipe _recipe() {
  return Recipe(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Base64 Decode',
    steps: <RecipeStep>[
      RecipeStep(id: 'step-1', operationId: 'test.base64_decode'),
    ],
    input: const TextBuffer('SGVsbG8='),
    output: const TextBuffer('Hello'),
  );
}

Widget _host({Recipe? recipe}) {
  final registry = OperationRegistry()
    ..registerOperation(
      const ReverseTextOperation(),
      pluginId: 'dev.bufferite.core',
      pluginVersion: '1.0.0',
      tier: RuntimeTier.dsl,
    )
    ..registerOperation(
      const Base64DecodeOperation(),
      pluginId: 'dev.bufferite.core',
      pluginVersion: '1.0.0',
      tier: RuntimeTier.dsl,
    );
  return ProviderScope(
    overrides: [operationRegistryProvider.overrideWithValue(registry)],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: RecipeEditorPage(recipe: recipe),
    ),
  );
}

void main() {
  testWidgets('editor baru menampilkan kerangka kosong', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.text('Recipe Baru'), findsOneWidget);
    expect(find.text('Nama recipe'), findsOneWidget);
    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Step'), findsOneWidget);
    expect(find.text('Output'), findsWidgets);
    expect(
      find.text('Belum ada step. Tambahkan operasi dari Library.'),
      findsOneWidget,
    );
    expect(find.text('Simpan'), findsOneWidget);
  });

  testWidgets('editor terisi menampilkan nama, step, dan output', (
    tester,
  ) async {
    await tester.pumpWidget(_host(recipe: _recipe()));
    await tester.pump();

    expect(find.text('Edit Recipe'), findsOneWidget);
    expect(find.text('Base64 Decode'), findsOneWidget);
    expect(find.text('test.base64_decode'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('toggle step mengubah status enabled', (tester) async {
    await tester.pumpWidget(_host(recipe: _recipe()));
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pump();
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isFalse);
  });

  testWidgets('reorder mengubah urutan step', (tester) async {
    final recipe = Recipe(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Dua Step',
      steps: <RecipeStep>[
        RecipeStep(id: 's1', operationId: 'core.alpha'),
        RecipeStep(id: 's2', operationId: 'core.beta'),
      ],
      input: const TextBuffer('x'),
    );
    await tester.pumpWidget(_host(recipe: recipe));
    await tester.pump();

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(0, 1);
    await tester.pump();

    final names = tester
        .widgetList<StepCard>(find.byType(StepCard))
        .map((card) => card.name)
        .toList();
    expect(names, <String>['core.beta', 'core.alpha']);
  });

  testWidgets('hapus step lalu Undo memulihkan', (tester) async {
    final recipe = Recipe(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Dua Step',
      steps: <RecipeStep>[
        RecipeStep(id: 's1', operationId: 'core.alpha'),
        RecipeStep(id: 's2', operationId: 'core.beta'),
      ],
      input: const TextBuffer('x'),
    );
    await tester.pumpWidget(_host(recipe: recipe));
    await tester.pump();

    await tester.tap(find.byTooltip('Hapus step').first);
    await tester.pump();
    expect(
      tester.widgetList<StepCard>(find.byType(StepCard)).map((c) => c.name),
      <String>['core.beta'],
    );

    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    expect(action.label, 'Undo');
    action.onPressed();
    await tester.pump();
    expect(
      tester.widgetList<StepCard>(find.byType(StepCard)).map((c) => c.name),
      <String>['core.alpha', 'core.beta'],
    );
  });

  testWidgets('Simpan menolak recipe tidak valid', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.textContaining('Nama recipe'), findsWidgets);
  });

  testWidgets('perubahan belum tersimpan dijaga dialog', (tester) async {
    await tester.pumpWidget(_host());
    await tester.enterText(find.byType(TextField).first, 'Draft');
    await tester.pump();

    final popped = await tester.binding.handlePopRoute();
    expect(popped, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Buang perubahan?'), findsOneWidget);

    await tester.tap(find.text('Buang'));
    await tester.pumpAndSettle();
  });

  testWidgets('menu menyediakan impor dan ekspor .brecipe', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.byTooltip('Lainnya'));
    await tester.pumpAndSettle();

    expect(find.text('Impor .brecipe'), findsOneWidget);
    expect(find.text('Ekspor .brecipe'), findsOneWidget);
  });

  testWidgets('ekspor recipe tidak valid menampilkan error', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.byTooltip('Lainnya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ekspor .brecipe'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nama recipe'), findsWidgets);
  });
}
