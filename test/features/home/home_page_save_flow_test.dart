import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/core/storage/storage_providers.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/home/home_page.dart';
import 'package:bufferite/features/operations/operation_providers.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_providers.dart';
import 'package:bufferite/features/recipe/recipe_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/support/async_pump.dart';
import '../../core/support/fake_operations.dart';

const String _recipeId = '11111111-1111-4111-8111-111111111111';

Recipe _recipe() {
  return Recipe(
    id: _recipeId,
    name: 'Base64 Decode',
    steps: <RecipeStep>[
      RecipeStep(id: 'step-1', operationId: 'test.base64_decode'),
    ],
    input: const TextBuffer('SGVsbG8='),
  );
}

OperationRegistry _registry() {
  return OperationRegistry()
    ..registerOperation(
      const Base64DecodeOperation(),
      pluginId: 'dev.bufferite.core',
      pluginVersion: '1.0.0',
      tier: RuntimeTier.dsl,
    )
    ..registerOperation(
      const ReverseTextOperation(),
      pluginId: 'dev.bufferite.core',
      pluginVersion: '1.0.0',
      tier: RuntimeTier.dsl,
    );
}

void main() {
  sqfliteFfiInit();

  testWidgets('menyimpan recipe memperbarui daftar Home', (tester) async {
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(database.close);
    final repository = RecipeRepository(database);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        operationRegistryProvider.overrideWithValue(_registry()),
      ],
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
    expect(find.text('Base64 Decode'), findsOneWidget);

    await tester.tap(find.text('Base64 Decode'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Recipe'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Base64 Updated');
    await tester.pump();

    await tester.tap(find.text('Simpan'));
    await tester.pump();

    await pumpUntil(
      tester,
      () =>
          find.text('Simpan').evaluate().isEmpty &&
          find.text('Base64 Updated').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(find.text('Base64 Updated'), findsOneWidget);
    expect(find.text('Base64 Decode'), findsNothing);
  });
}
