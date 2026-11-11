import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/step_card.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _recipe() {
  return Recipe(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Base64 Decode',
    steps: <RecipeStep>[
      RecipeStep(id: 'step-1', operationId: 'core.base64_decode'),
    ],
    input: const TextBuffer('SGVsbG8='),
    output: const TextBuffer('Hello'),
  );
}

Widget _host({Recipe? recipe}) {
  return ProviderScope(
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
    expect(find.text('core.base64_decode'), findsOneWidget);
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

  testWidgets('Simpan menampilkan toast', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.textContaining('Menyimpan recipe'), findsOneWidget);
  });
}
