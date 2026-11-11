import 'dart:io';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _idA = '11111111-1111-4111-8111-111111111111';
const _idB = '22222222-2222-4222-9222-222222222222';
const _idC = '33333333-3333-4333-a333-333333333333';

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
  late RecipeRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bufferite_recipe_repo_');
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/bufferite.db',
    );
    repository = RecipeRepository(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('save membuat recipe dan byId mengembalikannya', () async {
    final timestamp = DateTime.utc(2026, 1, 1, 10);
    final saved = await repository.save(
      _recipe(id: _idA, name: 'Recipe A'),
      now: timestamp,
    );

    expect(saved.meta?.createdAt, timestamp);
    expect(saved.meta?.updatedAt, timestamp);

    final loaded = await repository.byId(_idA);
    expect(loaded, saved);
    expect(await repository.byId(_idB), isNull);
  });

  test('list mengurutkan berdasarkan update terakhir', () async {
    await repository.save(
      _recipe(id: _idA, name: 'Recipe A'),
      now: DateTime.utc(2026, 1, 1, 10),
    );
    await repository.save(
      _recipe(id: _idB, name: 'Recipe B'),
      now: DateTime.utc(2026, 1, 1, 11),
    );
    await repository.save(
      _recipe(id: _idC, name: 'Recipe C'),
      now: DateTime.utc(2026, 1, 1, 12),
    );

    expect((await repository.list()).map((recipe) => recipe.id), <String>[
      _idC,
      _idB,
      _idA,
    ]);

    await repository.save(
      _recipe(id: _idA, name: 'Recipe A updated'),
      now: DateTime.utc(2026, 1, 1, 13),
    );

    final ordered = await repository.list();
    expect(ordered.map((recipe) => recipe.id), <String>[_idA, _idC, _idB]);
    expect(ordered.first.meta?.createdAt, DateTime.utc(2026, 1, 1, 10));
    expect(ordered.first.meta?.updatedAt, DateTime.utc(2026, 1, 1, 13));
    expect(ordered, hasLength(3));
  });

  test('pencarian nama case-insensitive dan literal', () async {
    await repository.save(_recipe(id: _idA, name: 'Base64 Decode'));
    await repository.save(_recipe(id: _idB, name: 'Hex Encode'));
    await repository.save(_recipe(id: _idC, name: '100% Literal'));

    expect(
      (await repository.list(query: 'base')).map((recipe) => recipe.id),
      <String>[_idA],
    );
    expect(
      (await repository.list(query: '  HEX  ')).map((recipe) => recipe.id),
      <String>[_idB],
    );
    expect(
      (await repository.list(query: '%')).map((recipe) => recipe.id),
      <String>[_idC],
    );
    expect(await repository.list(query: '_'), isEmpty);
    expect(await repository.list(query: ''), hasLength(3));
  });

  test('save dengan ID sama memperbarui tanpa menggandakan baris', () async {
    await repository.save(
      _recipe(id: _idA, name: 'Lama'),
      now: DateTime.utc(2026, 1, 1, 10),
    );
    final updated = await repository.save(
      _recipe(id: _idA, name: 'Baru'),
      now: DateTime.utc(2026, 1, 1, 11),
    );

    expect(updated.name, 'Baru');
    expect(updated.meta?.createdAt, DateTime.utc(2026, 1, 1, 10));
    expect(updated.meta?.updatedAt, DateTime.utc(2026, 1, 1, 11));
    expect(await repository.list(), hasLength(1));
  });

  test('delete menghapus recipe dan melaporkan apakah ada', () async {
    await repository.save(_recipe(id: _idA, name: 'Recipe A'));

    expect(await repository.delete(_idA), isTrue);
    expect(await repository.byId(_idA), isNull);
    expect(await repository.delete(_idA), isFalse);
    expect(await repository.list(), isEmpty);
  });

  test('save menolak recipe tidak valid', () async {
    expect(
      () => repository.save(_recipe(id: _idA, name: '')),
      throwsA(
        isA<AppError>()
            .having(
              (error) => error.category,
              'category',
              ErrorCategory.validation,
            )
            .having((error) => error.code, 'code', 'recipe.invalid'),
      ),
    );
    expect(await repository.list(), isEmpty);
  });

  test('data rusak menghasilkan error storage terstruktur', () async {
    final db = await appDatabase.open();
    final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    await db.insert('recipe', <String, Object?>{
      'id': _idA,
      'name': 'Rusak',
      'data': '{bukan json',
      'created_at': now,
      'updated_at': now,
    });

    expect(
      () => repository.byId(_idA),
      throwsA(
        isA<AppError>()
            .having(
              (error) => error.category,
              'category',
              ErrorCategory.storage,
            )
            .having((error) => error.code, 'code', 'storage.corrupt_recipe'),
      ),
    );
  });
}
