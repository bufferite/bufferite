import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/plugin/semantic_version.dart';
import 'package:bufferite/core/registry/registry_index.dart';
import 'package:bufferite/core/registry/registry_plugin_status.dart';
import 'package:flutter_test/flutter_test.dart';

final SemanticVersion _app = SemanticVersion.parse('1.5.0');

RegistryEntry _entry(
  String version, {
  String pluginId = 'com.test.pack',
  RegistryEntryStatus status = RegistryEntryStatus.active,
  String minAppVersion = '1.0.0',
}) {
  return RegistryEntry(
    pluginId: pluginId,
    version: SemanticVersion.parse(version),
    name: 'Test Pack',
    summary: 'Ringkasan.',
    tier: RuntimeTier.lua,
    minAppVersion: SemanticVersion.parse(minAppVersion),
    permissions: const <PluginPermission>{PluginPermission.cpu},
    sizeBytes: 1024,
    sha256: List<String>.filled(64, 'a').join(),
    downloadUrl: 'packages/$pluginId/$version/pack.berp',
    publishedAt: DateTime.utc(2026, 11, 20),
    status: status,
  );
}

RegistryIndex _index(List<RegistryEntry> entries) {
  return RegistryIndex(
    sequence: 1,
    generatedAt: DateTime.utc(2026, 11, 20),
    allowedHosts: const <String>['registry.test'],
    plugins: entries,
  );
}

void main() {
  test('update memilih rilis active tertinggi yang kompatibel', () {
    final status = registryStatusFor(
      pluginId: 'com.test.pack',
      installedVersion: SemanticVersion.parse('1.0.0'),
      index: _index(<RegistryEntry>[
        _entry('1.0.0'),
        _entry('1.1.0'),
        _entry('1.2.0', status: RegistryEntryStatus.yanked),
        _entry('2.0.0', minAppVersion: '2.0.0'),
      ]),
      appVersion: _app,
    );

    expect(status, isNotNull);
    expect(status!.hasUpdate, isTrue);
    expect(status.update!.version.toString(), '1.1.0');
    expect(status.isRevoked, isFalse);
  });

  test('tanpa rilis active yang lebih baru tidak ada update', () {
    final status = registryStatusFor(
      pluginId: 'com.test.pack',
      installedVersion: SemanticVersion.parse('1.1.0'),
      index: _index(<RegistryEntry>[_entry('1.0.0'), _entry('1.1.0')]),
      appVersion: _app,
    );

    expect(status!.hasUpdate, isFalse);
  });

  test('status terpasang melaporkan deprecated, yanked, dan revoked', () {
    for (final entry in <(RegistryEntryStatus, String)>[
      (RegistryEntryStatus.deprecated, 'deprecated'),
      (RegistryEntryStatus.yanked, 'yanked'),
      (RegistryEntryStatus.revoked, 'revoked'),
    ]) {
      final status = registryStatusFor(
        pluginId: 'com.test.pack',
        installedVersion: SemanticVersion.parse('1.0.0'),
        index: _index(<RegistryEntry>[
          _entry('1.0.0', status: entry.$1),
          _entry('1.1.0'),
        ]),
        appVersion: _app,
      );

      expect(status!.installedStatus, entry.$1, reason: entry.$2);
      expect(status.isDeprecated, entry.$1 == RegistryEntryStatus.deprecated);
      expect(status.isYanked, entry.$1 == RegistryEntryStatus.yanked);
      expect(status.isRevoked, entry.$1 == RegistryEntryStatus.revoked);
      expect(status.hasUpdate, isTrue);
    }
  });

  test('plugin yang tidak ada di indeks menghasilkan null', () {
    final status = registryStatusFor(
      pluginId: 'com.test.missing',
      installedVersion: SemanticVersion.parse('1.0.0'),
      index: _index(<RegistryEntry>[_entry('1.0.0')]),
      appVersion: _app,
    );

    expect(status, isNull);
  });

  test('registryReleasesFor mengurutkan rilis terbaru lebih dulu', () {
    final releases = registryReleasesFor(
      _index(<RegistryEntry>[
        _entry('1.0.0'),
        _entry('2.0.0'),
        _entry('1.5.0'),
        _entry('1.0.0', pluginId: 'com.test.other'),
      ]),
      'com.test.pack',
    );

    expect(releases.map((entry) => entry.version.toString()), <String>[
      '2.0.0',
      '1.5.0',
      '1.0.0',
    ]);
  });
}
