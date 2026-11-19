import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/buffer_panel.dart';
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

Future<void> _openSteps(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ingredients'));
  await tester.pumpAndSettle();
}

Future<void> _closeSteps(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Tutup panel ingredients'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('editor baru menampilkan kerangka kosong', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.text('Recipe Baru'), findsOneWidget);
    expect(find.text('Nama recipe'), findsOneWidget);
    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Output'), findsWidgets);
    expect(find.byType(StepCard), findsNothing);
    expect(find.text('Simpan'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(BufferPanel)).dy,
      greaterThan(tester.getTopLeft(find.byType(TextField).at(1)).dy),
    );

    await _openSteps(tester);
    expect(find.text('Ingredients (0)'), findsOneWidget);
    expect(
      find.text('Belum ada ingredients. Tambahkan operasi dari Library.'),
      findsOneWidget,
    );
    expect(find.text('Tambah ingredients'), findsOneWidget);
  });

  testWidgets('editor terisi menampilkan nama, step, dan output', (
    tester,
  ) async {
    await tester.pumpWidget(_host(recipe: _recipe()));
    await tester.pump();

    expect(find.text('Edit Recipe'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.byType(StepCard), findsNothing);

    await _openSteps(tester);
    expect(
      find.descendant(
        of: find.byType(StepCard),
        matching: find.text('Base64 Decode'),
      ),
      findsOneWidget,
    );
    expect(find.text('Encode/Decode'), findsOneWidget);
  });

  testWidgets('toggle step mengubah status enabled', (tester) async {
    await tester.pumpWidget(_host(recipe: _recipe()));
    await tester.pump();
    await _openSteps(tester);

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
    await _openSteps(tester);

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
    await _openSteps(tester);

    await tester.tap(find.byTooltip('Hapus ingredients').first);
    await tester.pumpAndSettle();
    expect(find.byType(StepCard), findsNothing);

    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    expect(action.label, 'Undo');
    action.onPressed();
    await tester.pump();

    await _openSteps(tester);
    expect(
      tester.widgetList<StepCard>(find.byType(StepCard)).map((c) => c.name),
      <String>['core.alpha', 'core.beta'],
    );
  });

  testWidgets('atur step membuka dialog konfigurasi', (tester) async {
    final recipe = Recipe(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Reverse',
      steps: <RecipeStep>[RecipeStep(id: 's1', operationId: 'test.reverse')],
      input: const TextBuffer('abc'),
    );
    await tester.pumpWidget(_host(recipe: recipe));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await _openSteps(tester);

    await tester.tap(find.byTooltip('Atur ingredients'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Uppercase'), findsOneWidget);
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

  testWidgets('menyediakan aksi pilih file input', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('Pilih file'), findsOneWidget);
  });

  testWidgets('alur: tambah step, live output, disable, simpan invalid', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await _openSteps(tester);

    await tester.tap(find.text('Tambah ingredients'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reverse Text'));
    await tester.pumpAndSettle();

    expect(find.byType(StepCard), findsOneWidget);
    await _closeSteps(tester);

    await tester.enterText(find.byType(TextField).at(1), 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.widget<BufferPanel>(find.byType(BufferPanel)).content, 'cba');

    await _openSteps(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await _closeSteps(tester);

    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.textContaining('Nama recipe'), findsWidgets);
  });
}
