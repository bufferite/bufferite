import 'package:bufferite/core/plugin/manifest_registrar.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pipeline_operations.dart';
import 'support/plugin_fixtures.dart';

void main() {
  group('ManifestRegistrar', () {
    test('mendaftarkan deskripsi operasi manifest', () {
      final registry = OperationRegistry();
      final manifest = PluginManifest.fromJson(validManifestJson());
      final executor = CountingOperation(
        id: 'test.operation',
        name: 'Test Operation',
      );

      final errors = ManifestRegistrar(
        registry,
      ).register(manifest, executorFor: (_) => executor);

      expect(errors, isEmpty);
      expect(registry.count, 1);
      final entry = registry.byId('test.operation');
      expect(entry, isNotNull);
      expect(entry!.descriptor.pluginId, 'com.test.pack');
      expect(entry.descriptor.available, isTrue);
      expect(registry.require('test.operation').isSuccess, isTrue);
    });

    test('menandai tier yang belum didukung sebagai unavailable', () {
      final registry = OperationRegistry();
      final manifest = PluginManifest.fromJson(validManifestJson());

      final errors = ManifestRegistrar(registry).register(
        manifest,
        supportedTiers: const <RuntimeTier>{RuntimeTier.dsl},
      );

      expect(errors, isEmpty);
      final entry = registry.byId('test.operation');
      expect(entry!.descriptor.available, isFalse);
      expect(
        registry.require('test.operation').errorOrNull?.code,
        'operation.unsupported',
      );
    });

    test('menandai plugin nonaktif sebagai unavailable', () {
      final registry = OperationRegistry();
      final manifest = PluginManifest.fromJson(validManifestJson());

      ManifestRegistrar(registry).register(manifest, enabled: false);

      expect(registry.byId('test.operation')!.descriptor.available, isFalse);
    });

    test('menangani ID operasi duplikat tanpa menghentikan sisanya', () {
      final registry = OperationRegistry();
      final registrar = ManifestRegistrar(registry);
      final first = PluginManifest.fromJson(
        validManifestJson(pluginId: 'com.first.pack'),
      );
      final second = PluginManifest.fromJson(
        validManifestJson(pluginId: 'com.second.pack'),
      );

      expect(registrar.register(first), isEmpty);
      final errors = registrar.register(second);

      expect(errors, hasLength(1));
      expect(errors.single.code, 'operation.duplicate_id');
      expect(
        registry.byId('test.operation')!.descriptor.pluginId,
        'com.first.pack',
      );
      expect(registry.warnings, hasLength(1));
    });
  });
}
