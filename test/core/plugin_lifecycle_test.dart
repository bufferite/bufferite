import 'package:bufferite/core/plugin/manifest_registrar.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/plugin/plugin_lifecycle.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pipeline_operations.dart';
import 'support/plugin_fixtures.dart';

OperationRegistry _registryWithPlugin({String pluginId = 'com.test.pack'}) {
  final registry = OperationRegistry();
  final manifest = PluginManifest.fromJson(
    validManifestJson(pluginId: pluginId),
  );
  ManifestRegistrar(registry).register(
    manifest,
    executorFor: (id) => CountingOperation(id: id, name: 'Test'),
  );
  return registry;
}

void main() {
  group('PluginLifecycleService', () {
    test('disable menyembunyikan operasi, enable mengembalikannya', () {
      final registry = _registryWithPlugin();
      final service = PluginLifecycleService(registry: registry);

      expect(registry.all(), hasLength(1));
      expect(service.disable('com.test.pack'), isEmpty);
      expect(registry.all(), isEmpty);
      expect(registry.all(includeUnsupported: true), hasLength(1));
      expect(
        registry.require('test.operation').errorOrNull?.code,
        'operation.unsupported',
      );

      expect(service.enable('com.test.pack'), isEmpty);
      expect(registry.all(), hasLength(1));
      expect(registry.require('test.operation').isSuccess, isTrue);
    });

    test('remove menghapus operasi dari registry', () {
      final registry = _registryWithPlugin();
      final service = PluginLifecycleService(registry: registry);

      service.remove('com.test.pack');

      expect(registry.byId('test.operation'), isNull);
      expect(registry.count, 0);
    });

    test('memberi peringatan saat core dinonaktifkan atau dihapus', () {
      final registry = _registryWithPlugin(pluginId: 'com.core.pack');
      final service = PluginLifecycleService(
        registry: registry,
        corePluginId: 'com.core.pack',
      );

      expect(service.disable('com.core.pack').single, contains('core'));
      expect(service.remove('com.core.pack').single, contains('core'));
    });
  });
}
