import 'dart:io';

import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/features/library/favorite_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late FavoriteRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bufferite_favorite_repo_');
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/bufferite.db',
    );
    repository = FavoriteRepository(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('add, contains, list, dan remove', () async {
    expect(await repository.list(), isEmpty);
    expect(await repository.contains('core.base64_decode'), isFalse);

    await repository.add('core.base64_decode');

    expect(await repository.contains('core.base64_decode'), isTrue);
    expect(await repository.list(), <String>['core.base64_decode']);
    expect(await repository.remove('core.base64_decode'), isTrue);
    expect(await repository.remove('core.base64_decode'), isFalse);
    expect(await repository.list(), isEmpty);
  });

  test('list mengurutkan favorit terbaru lebih dulu', () async {
    await repository.add(
      'core.base64_decode',
      now: DateTime.utc(2026, 1, 1, 10),
    );
    await repository.add('core.hex_encode', now: DateTime.utc(2026, 1, 1, 11));

    expect(await repository.list(), <String>[
      'core.hex_encode',
      'core.base64_decode',
    ]);
  });

  test('add duplikat tidak menggandakan atau mengubah urutan', () async {
    await repository.add(
      'core.base64_decode',
      now: DateTime.utc(2026, 1, 1, 10),
    );
    await repository.add('core.hex_encode', now: DateTime.utc(2026, 1, 1, 11));
    await repository.add(
      'core.base64_decode',
      now: DateTime.utc(2026, 1, 1, 12),
    );

    expect(await repository.list(), <String>[
      'core.hex_encode',
      'core.base64_decode',
    ]);
  });

  test('favorit persist setelah database dibuka ulang', () async {
    await repository.add('core.base64_decode');
    await appDatabase.close();

    final reopenedDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/bufferite.db',
    );
    final reopened = FavoriteRepository(reopenedDatabase);
    expect(await reopened.list(), <String>['core.base64_decode']);
    await reopenedDatabase.close();
  });

  test('menolak ID operasi kosong', () async {
    expect(() => repository.add('  '), throwsArgumentError);
  });
}
