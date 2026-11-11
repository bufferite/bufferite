import 'dart:io';

import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/plugin_package.dart';
import 'package:bufferite/core/plugin/plugin_package_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/plugin_fixtures.dart';

PluginPackage _package({
  String pluginId = 'com.test.pack',
  String version = '1.0.0',
  Map<String, String> files = const <String, String>{
    'main.lua': 'return function(input, args) return input end',
  },
}) {
  return PluginPackage.decode(
    buildPackageZip(
      manifest: validManifestJson(pluginId: pluginId, version: version),
      files: files,
    ),
  );
}

void main() {
  late Directory tempDir;
  late Directory root;
  late PluginPackageStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bufferite_pkg_store_');
    root = Directory('${tempDir.path}/plugins');
    store = PluginPackageStore(root);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('install mengekstrak manifest dan entrypoint', () async {
    final package = _package();
    final installPath = await store.install(package);

    expect(installPath, '${root.path}/com.test.pack/1.0.0');
    final manifest = File(
      '$installPath/plugin.manifest.json',
    ).readAsStringSync();
    expect(manifest, contains('"pluginId":"com.test.pack"'));
    final entrypoint = File('$installPath/main.lua').readAsBytesSync();
    expect(
      String.fromCharCodes(entrypoint),
      'return function(input, args) return input end',
    );
    expect(store.installPath('com.test.pack', '1.0.0'), installPath);
    expect(store.installPath('com.test.pack', '2.0.0'), isNull);
    expect(
      Directory('${root.path}/.staging').existsSync(),
      isFalse,
      reason: 'Direktori staging harus kosong setelah instalasi sukses.',
    );
  });

  test('install ulang versi sama mengganti isi', () async {
    await store.install(
      _package(
        files: const <String, String>{'main.lua': 'old', 'extra.lua': 'extra'},
      ),
    );

    await store.install(
      _package(files: const <String, String>{'main.lua': 'new'}),
    );

    final installPath = store.installPath('com.test.pack', '1.0.0')!;
    expect(File('$installPath/main.lua').readAsStringSync(), 'new');
    expect(File('$installPath/extra.lua').existsSync(), isFalse);
  });

  test('remove menghapus direktori plugin', () async {
    await store.install(_package());

    expect(await store.remove('com.test.pack'), isTrue);
    expect(store.installPath('com.test.pack', '1.0.0'), isNull);
    expect(await store.remove('com.test.pack'), isFalse);
  });

  test(
    'install gagal menghasilkan error terstruktur dan staging bersih',
    () async {
      final blocker = File('${tempDir.path}/blocker');
      blocker.writeAsStringSync('bukan direktori');
      final failingStore = PluginPackageStore(
        Directory('${blocker.path}/plugins'),
      );

      await expectLater(
        failingStore.install(_package()),
        throwsA(
          isA<AppError>()
              .having(
                (error) => error.category,
                'category',
                ErrorCategory.plugin,
              )
              .having((error) => error.code, 'code', 'plugin.install_failed'),
        ),
      );
      expect(
        Directory('${blocker.path}/plugins/.staging').existsSync(),
        isFalse,
      );
    },
  );

  test('menolak segmen path tidak valid', () async {
    await expectLater(
      store.remove('..'),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'plugin.install_path_invalid',
        ),
      ),
    );
    expect(
      () => store.installPath('com.test.pack', '..'),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'plugin.install_path_invalid',
        ),
      ),
    );
  });
}
