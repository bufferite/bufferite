import 'dart:io';

import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/features/plugins/plugin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/support/plugin_fixtures.dart';

InstalledPlugin _plugin({
  String pluginId = 'com.test.pack',
  String version = '1.0.0',
  PluginSource source = PluginSource.sideload,
  bool enabled = true,
  bool verified = false,
  String? installPath,
  DateTime? installedAt,
}) {
  return InstalledPlugin(
    manifest: PluginManifest.fromJson(
      validManifestJson(pluginId: pluginId, version: version),
    ),
    source: source,
    installedAt: installedAt ?? DateTime.utc(2026, 1, 1, 10),
    enabled: enabled,
    verified: verified,
    installPath: installPath,
  );
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late PluginRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bufferite_plugin_repo_');
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/bufferite.db',
    );
    repository = PluginRepository(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('save dan byId mempertahankan metadata terpasang', () async {
    final plugin = _plugin(
      source: PluginSource.registry,
      enabled: false,
      verified: true,
      installPath: '/plugins/com.test.pack/1.0.0',
    );

    await repository.save(plugin);

    final loaded = await repository.byId('com.test.pack');
    expect(loaded, isNotNull);
    expect(loaded!.pluginId, plugin.pluginId);
    expect(loaded.version, plugin.version);
    expect(loaded.source, PluginSource.registry);
    expect(loaded.installedAt, plugin.installedAt);
    expect(loaded.enabled, isFalse);
    expect(loaded.verified, isTrue);
    expect(loaded.installPath, plugin.installPath);
    expect(await repository.byId('com.missing'), isNull);
  });

  test('list mengurutkan berdasarkan waktu instalasi', () async {
    await repository.save(
      _plugin(
        pluginId: 'com.test.b',
        installedAt: DateTime.utc(2026, 1, 1, 11),
      ),
    );
    await repository.save(
      _plugin(
        pluginId: 'com.test.a',
        installedAt: DateTime.utc(2026, 1, 1, 10),
      ),
    );

    expect((await repository.list()).map((plugin) => plugin.pluginId), <String>[
      'com.test.a',
      'com.test.b',
    ]);
  });

  test('save ulang memperbarui versi dan mempertahankan instalasi', () async {
    await repository.save(_plugin(version: '1.0.0'));
    await repository.save(_plugin(version: '2.0.0', enabled: false));

    final loaded = await repository.byId('com.test.pack');
    expect(loaded!.version.toString(), '2.0.0');
    expect(loaded.enabled, isFalse);
    expect(loaded.installedAt, DateTime.utc(2026, 1, 1, 10));
    expect(await repository.list(), hasLength(1));
  });

  test('setEnabled mengubah status dan persist setelah reload', () async {
    await repository.save(_plugin());

    expect(await repository.setEnabled('com.test.pack', false), isTrue);
    expect((await repository.byId('com.test.pack'))!.enabled, isFalse);

    expect(await repository.setEnabled('com.test.pack', true), isTrue);
    expect((await repository.byId('com.test.pack'))!.enabled, isTrue);

    expect(await repository.setEnabled('com.missing', true), isFalse);
  });

  test(
    'update plugin tidak menghapus izin, delete menghapus cascade',
    () async {
      final db = await appDatabase.open();
      await repository.save(_plugin());
      await db.insert('plugin_permission', <String, Object?>{
        'plugin_id': 'com.test.pack',
        'permission': 'net',
        'granted': 1,
      });

      await repository.save(_plugin(enabled: false));
      expect(await db.query('plugin_permission'), hasLength(1));

      expect(await repository.delete('com.test.pack'), isTrue);
      expect(await db.query('plugin_permission'), isEmpty);
      expect(await repository.delete('com.test.pack'), isFalse);
    },
  );

  test('data plugin rusak menghasilkan error storage terstruktur', () async {
    final db = await appDatabase.open();
    await db.insert('plugin', <String, Object?>{
      'plugin_id': 'com.test.pack',
      'version': '1.0.0',
      'source': 'sideload',
      'enabled': 1,
      'verified': 0,
      'installed_at': 0,
      'data': '{}',
    });

    expect(
      () => repository.byId('com.test.pack'),
      throwsA(
        isA<AppError>()
            .having(
              (error) => error.category,
              'category',
              ErrorCategory.storage,
            )
            .having((error) => error.code, 'code', 'storage.corrupt_plugin'),
      ),
    );
  });
}
