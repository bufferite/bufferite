import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/core/plugin/plugin_package.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/plugin/semantic_version.dart';
import 'package:bufferite/core/registry/registry_index.dart';
import 'package:bufferite/core/registry/registry_plugin_status.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/plugins/plugin_actions.dart';
import 'package:bufferite/features/plugins/plugin_manager_page.dart';
import 'package:bufferite/features/plugins/plugin_providers.dart';
import 'package:bufferite/features/plugins/plugin_sideload.dart';
import 'package:bufferite/features/plugins/registry/registry_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/support/plugin_fixtures.dart';

InstalledPlugin _plugin({
  bool enabled = true,
  bool verified = true,
  String version = '1.0.0',
}) {
  return InstalledPlugin(
    manifest: PluginManifest.fromJson(validManifestJson(version: version)),
    source: PluginSource.sideload,
    installedAt: DateTime.utc(2026, 1, 1),
    enabled: enabled,
    verified: verified,
  );
}

RegistryEntry _entry({
  String version = '1.1.0',
  RegistryEntryStatus status = RegistryEntryStatus.active,
}) {
  return RegistryEntry(
    pluginId: 'com.test.pack',
    version: SemanticVersion.parse(version),
    name: 'Test Pack',
    summary: 'Ringkasan.',
    tier: RuntimeTier.lua,
    minAppVersion: SemanticVersion.parse('1.0.0'),
    permissions: const <PluginPermission>{PluginPermission.cpu},
    sizeBytes: 1024,
    sha256: List<String>.filled(64, 'a').join(),
    downloadUrl: 'packages/com.test.pack/$version/pack.berp',
    publishedAt: DateTime.utc(2026, 11, 20),
    status: status,
  );
}

PluginRegistryStatus _status({
  RegistryEntry? update,
  RegistryEntryStatus? installedStatus,
}) {
  return PluginRegistryStatus(
    installedVersion: SemanticVersion.parse('1.0.0'),
    installedRelease: installedStatus == null
        ? _entry(version: '1.0.0')
        : _entry(version: '1.0.0', status: installedStatus),
    latestRelease: update,
    update: update,
  );
}

class FakePluginActions extends PluginActions {
  FakePluginActions(super.ref);

  final List<String> enabledCalls = <String>[];
  final List<String> removedCalls = <String>[];

  @override
  Future<bool> setEnabled(String pluginId, bool enabled) async {
    enabledCalls.add('$pluginId:$enabled');
    return true;
  }

  @override
  Future<bool> remove(String pluginId) async {
    removedCalls.add(pluginId);
    return true;
  }
}

class FakePluginSideload extends PluginSideloadService {
  FakePluginSideload(super.ref);

  int installs = 0;
  late final PluginPackage package = PluginPackage.decode(buildPackageZip());

  @override
  Future<PluginPackage?> pick({String? dialogTitle}) async => package;

  @override
  Future<InstalledPlugin> install(PluginPackage package) async {
    installs++;
    return _plugin();
  }
}

late FakePluginActions capturedActions;
late FakePluginSideload capturedSideload;

Widget _host(
  List<InstalledPlugin> plugins, {
  bool withActions = false,
  bool withSideload = false,
  Map<String, PluginRegistryStatus>? registryStatuses,
}) {
  return ProviderScope(
    overrides: [
      installedPluginsProvider.overrideWith((ref) => plugins),
      appVersionProvider.overrideWithValue(SemanticVersion.parse('1.0.0')),
      if (registryStatuses != null)
        registryPluginStatusesProvider.overrideWithValue(registryStatuses),
      if (withActions)
        pluginActionsProvider.overrideWith((ref) {
          capturedActions = FakePluginActions(ref);
          return capturedActions;
        }),
      if (withSideload)
        pluginSideloadProvider.overrideWith((ref) {
          capturedSideload = FakePluginSideload(ref);
          return capturedSideload;
        }),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const PluginManagerPage(),
    ),
  );
}

void main() {
  testWidgets('empty state saat belum ada plugin', (tester) async {
    await tester.pumpWidget(_host(const <InstalledPlugin>[]));
    await tester.pump();

    expect(find.text('Belum ada plugin terpasang'), findsOneWidget);
  });

  testWidgets('menampilkan versi, sumber, izin, tier, dan status', (
    tester,
  ) async {
    await tester.pumpWidget(_host(<InstalledPlugin>[_plugin()]));
    await tester.pump();

    expect(find.text('Test Pack'), findsOneWidget);
    expect(find.textContaining('v1.0.0'), findsOneWidget);
    expect(find.textContaining('Sumber: sideload'), findsOneWidget);
    expect(find.text('lua'), findsOneWidget);
    expect(find.text('aktif'), findsOneWidget);
  });

  testWidgets('plugin sideload belum terverifikasi menampilkan badge', (
    tester,
  ) async {
    await tester.pumpWidget(_host(<InstalledPlugin>[_plugin(verified: false)]));
    await tester.pump();

    expect(find.text('unverified'), findsOneWidget);
  });

  testWidgets('badge update tampil saat registry punya rilis lebih baru', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        <InstalledPlugin>[_plugin()],
        registryStatuses: <String, PluginRegistryStatus>{
          'com.test.pack': _status(update: _entry()),
        },
      ),
    );
    await tester.pump();

    expect(find.text('Update v1.1.0 tersedia'), findsOneWidget);
  });

  testWidgets('banner darurat tampil untuk plugin revoked', (tester) async {
    await tester.pumpWidget(
      _host(
        <InstalledPlugin>[_plugin(enabled: false)],
        registryStatuses: <String, PluginRegistryStatus>{
          'com.test.pack': _status(
            installedStatus: RegistryEntryStatus.revoked,
          ),
        },
      ),
    );
    await tester.pump();

    expect(find.textContaining('dinonaktifkan'), findsOneWidget);
    expect(find.text('revoked'), findsOneWidget);
  });

  testWidgets('tap plugin membuka detail manifest', (tester) async {
    await tester.pumpWidget(_host(<InstalledPlugin>[_plugin()]));
    await tester.pump();

    await tester.tap(find.text('Test Pack'));
    await tester.pumpAndSettle();

    expect(find.text('Manifest'), findsOneWidget);
    expect(find.text('com.test.pack'), findsOneWidget);
  });

  testWidgets('toggle enable memanggil aksi plugin', (tester) async {
    await tester.pumpWidget(
      _host(<InstalledPlugin>[_plugin()], withActions: true),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Aksi plugin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nonaktifkan'));
    await tester.pumpAndSettle();

    expect(capturedActions.enabledCalls, <String>['com.test.pack:false']);
  });

  testWidgets('hapus plugin dengan konfirmasi', (tester) async {
    await tester.pumpWidget(
      _host(<InstalledPlugin>[_plugin()], withActions: true),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Aksi plugin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(capturedActions.removedCalls, <String>['com.test.pack']);
  });

  testWidgets('sideload menampilkan preview lalu hasil', (tester) async {
    await tester.pumpWidget(
      _host(const <InstalledPlugin>[], withSideload: true),
    );
    await tester.pump();

    await tester.tap(find.text('Instal dari file'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Test Pack'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Instal'));
    await tester.pumpAndSettle();

    expect(capturedSideload.installs, 1);
  });
}
