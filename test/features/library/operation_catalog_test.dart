import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/features/library/operation_catalog.dart';
import 'package:bufferite/features/operations/operation_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/support/fake_operations.dart';
import '../../core/support/plugin_fixtures.dart';

OperationRegistry _registry() {
  final registry = OperationRegistry();
  registry.registerOperation(
    const ReverseTextOperation(),
    pluginId: 'com.test.pack',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  registry.registerOperation(
    const Base64DecodeOperation(),
    pluginId: 'com.test.pack',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  return registry;
}

InstalledPlugin _plugin({bool enabled = true, bool verified = true}) {
  return InstalledPlugin(
    manifest: PluginManifest.fromJson(validManifestJson()),
    source: PluginSource.sideload,
    installedAt: DateTime.utc(2026, 1, 1),
    enabled: enabled,
    verified: verified,
  );
}

void main() {
  test('katalog menggabungkan registry dan metadata plugin', () {
    final container = ProviderContainer(
      overrides: [
        operationRegistryProvider.overrideWithValue(_registry()),
        pluginMetadataProvider.overrideWithValue(<String, InstalledPlugin>{
          'com.test.pack': _plugin(),
        }),
      ],
    );
    addTearDown(container.dispose);

    final catalog = container.read(operationCatalogProvider);
    expect(catalog, hasLength(2));
    expect(catalog.map((entry) => entry.name), <String>[
      'Base64 Decode',
      'Reverse Text',
    ]);
    expect(catalog.every((entry) => entry.pluginName == 'Test Pack'), isTrue);
    expect(catalog.every((entry) => entry.enabled), isTrue);
  });

  test('plugin nonaktif disembunyikan dari katalog', () {
    final container = ProviderContainer(
      overrides: [
        operationRegistryProvider.overrideWithValue(_registry()),
        pluginMetadataProvider.overrideWithValue(<String, InstalledPlugin>{
          'com.test.pack': _plugin(enabled: false),
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(operationCatalogProvider), isEmpty);
  });

  test('plugin tanpa metadata (core) dianggap aktif', () {
    final container = ProviderContainer(
      overrides: [operationRegistryProvider.overrideWithValue(_registry())],
    );
    addTearDown(container.dispose);

    final catalog = container.read(operationCatalogProvider);
    expect(catalog, hasLength(2));
    expect(catalog.every((entry) => entry.pluginName == null), isTrue);
    expect(catalog.every((entry) => entry.verified), isTrue);
  });
}
