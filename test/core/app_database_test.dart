import 'dart:io';

import 'package:bufferite/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String databasePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bufferite_db_test_');
    databasePath = '${tempDir.path}/bufferite.db';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('membuka database, membuat schema v1, dan menutupnya', () async {
    final appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );

    final db = await appDatabase.open();
    expect(appDatabase.isOpen, isTrue);
    expect(await db.getVersion(), AppDatabase.schemaVersion);

    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tableNames = rows
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();
    expect(tableNames, containsAll(AppDatabase.tables));

    await appDatabase.close();
    expect(appDatabase.isOpen, isFalse);
    await appDatabase.close();
  });

  test('data dan schema bertahan setelah reopen', () async {
    final first = AppDatabase(factory: databaseFactoryFfi, path: databasePath);
    final db = await first.open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('recipe', <String, Object?>{
      'id': 'recipe-1',
      'name': 'Recipe',
      'data': '{}',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('plugin', <String, Object?>{
      'plugin_id': 'com.test.pack',
      'version': '1.0.0',
      'source': 'sideload',
      'enabled': 1,
      'verified': 0,
      'installed_at': now,
      'data': '{}',
    });
    await db.insert('setting', <String, Object?>{
      'key': 'theme',
      'value': 'system',
    });
    await db.insert('favorite', <String, Object?>{
      'operation_id': 'core.base64_decode',
      'created_at': now,
    });
    await db.insert('plugin_permission', <String, Object?>{
      'plugin_id': 'com.test.pack',
      'permission': 'cpu',
      'granted': 1,
    });
    await first.close();

    final second = AppDatabase(factory: databaseFactoryFfi, path: databasePath);
    final reopened = await second.open();
    expect(await reopened.getVersion(), AppDatabase.schemaVersion);
    expect((await reopened.query('recipe')).single['name'], 'Recipe');
    expect(
      (await reopened.query('plugin')).single['plugin_id'],
      'com.test.pack',
    );
    expect((await reopened.query('setting')).single['value'], 'system');
    expect(await reopened.query('favorite'), hasLength(1));
    expect(await reopened.query('plugin_permission'), hasLength(1));
    await second.close();
  });

  test('foreign key permission ikut terhapus saat plugin dihapus', () async {
    final appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    final db = await appDatabase.open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('plugin', <String, Object?>{
      'plugin_id': 'com.test.pack',
      'version': '1.0.0',
      'source': 'sideload',
      'enabled': 1,
      'verified': 0,
      'installed_at': now,
      'data': '{}',
    });
    await db.insert('plugin_permission', <String, Object?>{
      'plugin_id': 'com.test.pack',
      'permission': 'cpu',
      'granted': 1,
    });

    await db.delete(
      'plugin',
      where: 'plugin_id = ?',
      whereArgs: <Object?>['com.test.pack'],
    );

    expect(await db.query('plugin_permission'), isEmpty);
    await appDatabase.close();
  });

  test('migrasi v0 ke v1 membuat seluruh tabel', () async {
    final raw = await databaseFactoryFfi.openDatabase(databasePath);
    expect(await raw.getVersion(), 0);

    await AppDatabase.migrate(raw, 0, 1);

    final rows = await raw.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tableNames = rows
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();
    expect(tableNames, containsAll(AppDatabase.tables));
    await raw.close();
  });

  test('menolak migrasi yang belum tersedia', () async {
    final raw = await databaseFactoryFfi.openDatabase(databasePath);
    expect(() => AppDatabase.migrate(raw, 1, 2), throwsA(isA<StateError>()));
    await raw.close();
  });
}
