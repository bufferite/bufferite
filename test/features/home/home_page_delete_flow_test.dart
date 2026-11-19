import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/core/storage/storage_providers.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/home/home_page.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_providers.dart';
import 'package:bufferite/features/recipe/recipe_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/support/async_pump.dart';

const String _recipeId = '11111111-1111-4111-8111-111111111111';

Recipe _recipe() {
  return Recipe(
    id: _recipeId,
    name: 'Alpha',
    steps: <RecipeStep>[
      RecipeStep(id: 'step-1', operationId: 'core.reverse'),
    ],
    input: const TextBuffer('halo'),
  );
}

/// Menyiapkan database berisi satu recipe dan membuka Home.
Future<RecipeRepository> _pumpHome(WidgetTester tester) async {
  final database = AppDatabase(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
  );
  addTearDown(database.close);
  final repository = RecipeRepository(database);
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );
  addTearDown(container.dispose);

  await tester.runAsync(() async {
    await repository.save(_recipe());
    await container.read(recentRecipesProvider.future);
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const HomePage()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Alpha'), findsOneWidget);
  return repository;
}

void main() {
  sqfliteFfiInit();

  testWidgets('menu hapus menghapus recipe dari daftar Home', (tester) async {
    final repository = await _pumpHome(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus recipe?'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pump();

    await pumpUntil(tester, () => find.text('Alpha').evaluate().isEmpty);
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsNothing);
    await tester.runAsync(() async {
      expect(await repository.list(), isEmpty);
    });
  });

  testWidgets('swipe kiri + konfirmasi menghapus recipe', (tester) async {
    final repository = await _pumpHome(tester);

    await tester.drag(find.text('Alpha'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Hapus recipe?'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pump();

    await pumpUntil(tester, () => find.text('Alpha').evaluate().isEmpty);
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsNothing);
    await tester.runAsync(() async {
      expect(await repository.list(), isEmpty);
    });
  });
}
