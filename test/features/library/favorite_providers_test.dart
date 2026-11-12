import 'dart:io';

import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/core/storage/storage_providers.dart';
import 'package:bufferite/features/library/favorite_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase appDatabase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bufferite_favorites_');
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

  test('toggle menambah lalu menghapus favorit', () async {
    final ref = container();
    expect(await ref.read(favoritesProvider.future), isEmpty);

    await ref.read(favoritesProvider.notifier).toggle('test.reverse');
    expect(ref.read(favoritesProvider).value, <String>{'test.reverse'});

    await ref.read(favoritesProvider.notifier).toggle('test.reverse');
    expect(ref.read(favoritesProvider).value, isEmpty);
  });

  test('favorit persist antar container', () async {
    final first = container();
    await first.read(favoritesProvider.future);
    await first.read(favoritesProvider.notifier).toggle('test.reverse');

    final second = container();
    expect(await second.read(favoritesProvider.future), <String>{
      'test.reverse',
    });
  });
}
