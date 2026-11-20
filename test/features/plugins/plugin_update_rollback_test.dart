import 'dart:convert';
import 'dart:typed_data';

import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/core/plugin/plugin_package.dart';
import 'package:bufferite/core/runtime/plugin_runtime.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/features/plugins/plugin_manager_service.dart';
import 'package:bufferite/features/plugins/plugin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/support/plugin_fixtures.dart';

/// Store versi in-memory yang meniru `PluginPackageStore`.
final class _FakeStore {
  final Map<String, PluginPackage> packages = <String, PluginPackage>{};

  String path(String pluginId, String version) => '/plugins/$pluginId/$version';

  String _key(String pluginId, String version) => '$pluginId@$version';

  Future<String> write(PluginPackage package) async {
    final manifest = package.manifest;
    final version = manifest.version.toString();
    packages[_key(manifest.pluginId, version)] = package;
    return path(manifest.pluginId, version);
  }

  Future<PluginManifest?> readManifest(String pluginId, String version) async =>
      packages[_key(pluginId, version)]?.manifest;

  Future<String?> resolve(String pluginId, String version) async =>
      packages.containsKey(_key(pluginId, version))
      ? path(pluginId, version)
      : null;

  Future<void> removeVersion(String pluginId, String version) async {
    packages.remove(_key(pluginId, version));
  }

  Future<void> prune(String pluginId, Set<String> keep) async {
    final prefix = '$pluginId@';
    packages.removeWhere((key, value) {
      if (!key.startsWith(prefix)) {
        return false;
      }
      return !keep.contains(value.manifest.version.toString());
    });
  }

  Set<String> versions(String pluginId) {
    final prefix = '$pluginId@';
    return packages.keys
        .where((key) => key.startsWith(prefix))
        .map((key) => key.substring(prefix.length))
        .toSet();
  }
}

PluginPackage _package(String version) {
  return PluginPackage.decode(
    buildPackageZip(manifest: validManifestJson(version: version)),
  );
}

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late PluginRepository repository;
  late OperationRegistry registry;
  late _FakeStore store;
  late PluginManagerService service;

  setUp(() async {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = PluginRepository(database);
    registry = OperationRegistry();
    store = _FakeStore();
    service = PluginManagerService(
      repository: repository,
      registry: registry,
      writePackage: store.write,
      readManifest: store.readManifest,
      resolveInstallPath: store.resolve,
      removeVersion: store.removeVersion,
      pruneVersions: store.prune,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('update mempertahankan status enable dan menyimpan dua versi', () async {
    await service.install(_package('1.0.0'), source: PluginSource.sideload);
    await service.setEnabled('com.test.pack', false);

    final updated = await service.update(
      _package('2.0.0'),
      source: PluginSource.registry,
      verified: true,
      provenance: PluginProvenance(
        registryUrl: 'https://registry.test/registry.json',
        keyId: 'package-test',
        sha256: 'a' * 64,
        previousVersion: '1.0.0',
        previousSource: PluginSource.sideload,
        previousVerified: false,
      ),
    );

    expect(updated.version.toString(), '2.0.0');
    expect(updated.enabled, isFalse);
    expect(store.versions('com.test.pack'), <String>{'1.0.0', '2.0.0'});
    final stored = await repository.byId('com.test.pack');
    expect(stored!.version.toString(), '2.0.0');
    expect(stored.provenance!.previousVersion, '1.0.0');
    expect(stored.provenance!.previousSource, PluginSource.sideload);
    expect(registry.byId('test.operation')!.descriptor.pluginVersion, '2.0.0');

    await service.update(
      _package('3.0.0'),
      source: PluginSource.registry,
      verified: true,
      provenance: PluginProvenance(
        registryUrl: 'https://registry.test/registry.json',
        keyId: 'package-test',
        sha256: 'b' * 64,
        previousVersion: '2.0.0',
      ),
    );

    expect(store.versions('com.test.pack'), <String>{'2.0.0', '3.0.0'});
  });

  test('aktivasi gagal memulihkan versi lama secara otomatis', () async {
    final failing = PluginManagerService(
      repository: repository,
      registry: registry,
      writePackage: store.write,
      readManifest: store.readManifest,
      resolveInstallPath: store.resolve,
      removeVersion: store.removeVersion,
      pruneVersions: store.prune,
      runtimeLoader: PluginRuntimeLoader(
        sandboxConfig: () => SandboxConfig.defaults,
        readEntrypoint: (path) async => Uint8List.fromList(
          utf8.encode(
            path.contains('/2.0.0/')
                ? 'function transform(input)'
                : 'function transform(input) return input end',
          ),
        ),
      ),
    );

    await failing.install(_package('1.0.0'), source: PluginSource.sideload);

    await expectLater(
      failing.update(
        _package('2.0.0'),
        source: PluginSource.registry,
        verified: true,
        provenance: PluginProvenance(
          registryUrl: 'https://registry.test/registry.json',
          keyId: 'package-test',
          sha256: 'a' * 64,
          previousVersion: '1.0.0',
        ),
      ),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'plugin.update_failed',
        ),
      ),
    );

    final stored = await repository.byId('com.test.pack');
    expect(stored!.version.toString(), '1.0.0');
    expect(stored.enabled, isTrue);
    expect(store.versions('com.test.pack'), <String>{'1.0.0'});
    expect(registry.byId('test.operation')!.descriptor.pluginVersion, '1.0.0');
  });

  test('rollback manual memakai manifest versi sebelumnya', () async {
    await service.install(_package('1.0.0'), source: PluginSource.sideload);
    await service.setEnabled('com.test.pack', false);
    await service.update(
      _package('2.0.0'),
      source: PluginSource.registry,
      verified: true,
      provenance: PluginProvenance(
        registryUrl: 'https://registry.test/registry.json',
        keyId: 'package-test',
        sha256: 'a' * 64,
        previousVersion: '1.0.0',
        previousSource: PluginSource.sideload,
        previousVerified: false,
      ),
    );

    final restored = await service.rollback('com.test.pack');

    expect(restored.version.toString(), '1.0.0');
    expect(restored.enabled, isFalse);
    expect(restored.source, PluginSource.sideload);
    expect(restored.verified, isFalse);
    expect(restored.provenance!.previousVersion, '2.0.0');
    expect(store.versions('com.test.pack'), <String>{'1.0.0', '2.0.0'});
    expect(registry.byId('test.operation')!.descriptor.pluginVersion, '1.0.0');
  });

  test('downgrade eksplisit lewat update mempertahankan dua versi', () async {
    await service.install(
      _package('2.0.0'),
      source: PluginSource.registry,
      verified: true,
    );

    final downgraded = await service.update(
      _package('1.0.0'),
      source: PluginSource.registry,
      verified: true,
      provenance: PluginProvenance(
        registryUrl: 'https://registry.test/registry.json',
        keyId: 'package-test',
        sha256: 'a' * 64,
        previousVersion: '2.0.0',
        previousSource: PluginSource.registry,
        previousVerified: true,
      ),
    );

    expect(downgraded.version.toString(), '1.0.0');
    expect(store.versions('com.test.pack'), <String>{'1.0.0', '2.0.0'});
  });

  test('rollback tanpa versi sebelumnya ditolak', () async {
    await service.install(_package('1.0.0'), source: PluginSource.sideload);

    await expectLater(
      service.rollback('com.test.pack'),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'plugin.rollback_unavailable',
        ),
      ),
    );
  });
}
