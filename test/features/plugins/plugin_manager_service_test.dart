import 'dart:convert';
import 'dart:typed_data';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_param.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/plugin/plugin_package.dart';
import 'package:bufferite/core/runtime/plugin_runtime.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/features/plugins/plugin_manager_service.dart';
import 'package:bufferite/features/plugins/plugin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/support/plugin_fixtures.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late PluginRepository repository;
  late OperationRegistry registry;
  late List<PluginPackage> written;
  late PluginManagerService service;

  setUp(() async {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = PluginRepository(database);
    registry = OperationRegistry();
    written = <PluginPackage>[];
    service = PluginManagerService(
      repository: repository,
      registry: registry,
      writePackage: (package) async {
        written.add(package);
        return '/plugins/${package.manifest.pluginId}';
      },
    );
  });

  tearDown(() async {
    await database.close();
  });

  PluginPackage package({
    String pluginId = 'com.test.pack',
    String version = '1.0.0',
    String operationId = 'test.operation',
  }) {
    return PluginPackage.decode(
      buildPackageZip(
        manifest: validManifestJson(
          pluginId: pluginId,
          version: version,
          operationId: operationId,
        ),
      ),
    );
  }

  test('instal menyimpan paket, metadata, dan operasi registry', () async {
    final plugin = await service.install(
      package(),
      source: PluginSource.sideload,
    );

    expect(written, hasLength(1));
    expect(plugin.source, PluginSource.sideload);
    expect(plugin.verified, isFalse);
    expect(plugin.installPath, '/plugins/com.test.pack');
    expect(
      (await repository.byId('com.test.pack'))!.version.toString(),
      '1.0.0',
    );
    expect(registry.contains('test.operation'), isTrue);
    expect(registry.byPlugin('com.test.pack').single.executor, isNull);
  });

  test('instal ulang mengganti descriptor tanpa duplikat', () async {
    await service.install(package(), source: PluginSource.sideload);
    await service.install(
      package(version: '2.0.0'),
      source: PluginSource.registry,
      verified: true,
    );

    expect(await repository.list(), hasLength(1));
    expect(registry.count, 1);
    expect(
      registry.byPlugin('com.test.pack').single.descriptor.pluginVersion,
      '2.0.0',
    );
  });

  test('setEnabled menonaktifkan dan mengaktifkan operasi', () async {
    await service.install(package(), source: PluginSource.sideload);

    expect(await service.setEnabled('com.test.pack', false), isTrue);
    expect((await repository.byId('com.test.pack'))!.enabled, isFalse);
    expect(registry.byId('test.operation')!.descriptor.available, isFalse);

    expect(await service.setEnabled('com.test.pack', true), isTrue);
    expect(registry.byId('test.operation')!.descriptor.available, isTrue);

    expect(await service.setEnabled('com.missing', true), isFalse);
  });

  test('remove menghapus metadata dan operasi', () async {
    await service.install(package(), source: PluginSource.sideload);

    expect(await service.remove('com.test.pack'), isTrue);
    expect(await repository.byId('com.test.pack'), isNull);
    expect(registry.contains('test.operation'), isFalse);
    expect(await service.remove('com.test.pack'), isFalse);
  });

  test('restore mendaftarkan semua plugin terpasang', () async {
    await service.install(
      package(pluginId: 'com.test.a', operationId: 'test.a'),
      source: PluginSource.sideload,
    );
    await service.install(
      package(pluginId: 'com.test.b', operationId: 'test.b'),
      source: PluginSource.sideload,
    );
    registry.clear();

    final restored = await service.restore();

    expect(restored, hasLength(2));
    expect(
      registry
          .all(includeUnsupported: true)
          .map((entry) => entry.descriptor.id)
          .toSet(),
      <String>{'test.a', 'test.b'},
    );
  });

  test('executorFor dipakai untuk operasi core', () async {
    final coreService = PluginManagerService(
      repository: repository,
      registry: registry,
      writePackage: (package) async => '/plugins/core',
      executorFor: (operationId) =>
          operationId == 'test.operation' ? _FakeOperation() : null,
    );

    await coreService.install(package(), source: PluginSource.core);

    expect(registry.byId('test.operation')!.executor, isNotNull);
  });

  test('runtimeLoader menghasilkan executor plugin yang bisa dieksekusi',
      () async {
    final pluginService = PluginManagerService(
      repository: repository,
      registry: registry,
      writePackage: (package) async => '/plugins/com.test.pack',
      runtimeLoader: PluginRuntimeLoader(
        sandboxConfig: () => SandboxConfig.defaults,
        readEntrypoint: (path) async => Uint8List.fromList(
          utf8.encode(
            'function transform(input) return string.upper(input) end',
          ),
        ),
      ),
    );

    await pluginService.install(package(), source: PluginSource.sideload);

    final executor = registry.byId('test.operation')!.executor;
    expect(executor, isNotNull);
    final output = await executor!.execute(
      const TextBuffer('bufferite'),
      const <String, Object?>{},
    );
    expect(output.asText(), 'BUFFERITE');
  });
}

/// Executor dummy untuk memastikan injeksi executor bekerja.
final class _FakeOperation implements Operation {
  @override
  String get id => 'test.operation';

  @override
  String get name => 'Fake';

  @override
  OperationCategory get category => OperationCategory.utility;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io =>
      const OperationIO(input: BufferKind.text, output: BufferKind.text);

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async =>
      input;
}
