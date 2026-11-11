import 'dart:io';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/core/storage/storage_providers.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Recipe _recipe({required String id, required String name}) {
  return Recipe(
    id: id,
    name: name,
    steps: <RecipeStep>[
      RecipeStep(id: 'step-$id', operationId: 'core.reverse'),
    ],
    input: const TextBuffer('halo'),
  );
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase appDatabase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bufferite_recipe_prov_');
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/bufferite.db',
    );
  });

  tearDown(() async {
    await appDatabase.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ProviderContainer container() {
    final result = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
    );
    addTearDown(result.dispose);
    return result;
  }

  test('recentRecipesProvider mengembalikan urutan terbaru', () async {
    final ref = container();
    final repository = ref.read(recipeRepositoryProvider);
    await repository.save(
      _recipe(id: '11111111-1111-4111-8111-111111111111', name: 'Alpha'),
      now: DateTime.utc(2026, 1, 1, 10),
    );
    await repository.save(
      _recipe(id: '22222222-2222-4222-9222-222222222222', name: 'Beta'),
      now: DateTime.utc(2026, 1, 1, 11),
    );

    final recipes = await ref.read(recentRecipesProvider.future);
    expect(recipes.map((recipe) => recipe.name), <String>['Beta', 'Alpha']);
  });

  test('recipeSearchProvider memfilter nama', () async {
    final ref = container();
    final repository = ref.read(recipeRepositoryProvider);
    await repository.save(
      _recipe(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Base64 Decode',
      ),
    );
    await repository.save(
      _recipe(id: '22222222-2222-4222-9222-222222222222', name: 'Hex Encode'),
    );

    final found = await ref.read(recipeSearchProvider('base').future);
    expect(found.map((recipe) => recipe.name), <String>['Base64 Decode']);
    expect(await ref.read(recipeSearchProvider('zzz').future), isEmpty);
  });

  test('database kosong menghasilkan daftar kosong', () async {
    expect(await container().read(recentRecipesProvider.future), isEmpty);
  });
}
