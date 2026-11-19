import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/plugin/semantic_version.dart';
import 'package:bufferite/core/registry/registry_client.dart';
import 'package:bufferite/core/registry/registry_index.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/plugins/plugin_providers.dart';
import 'package:bufferite/features/plugins/registry/registry_catalog_screen.dart';
import 'package:bufferite/features/plugins/registry/registry_detail_screen.dart';
import 'package:bufferite/features/plugins/registry/registry_providers.dart';
import 'package:bufferite/features/settings/settings_provider.dart';
import 'package:bufferite/features/settings/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/support/plugin_fixtures.dart';

final Uri _sourceUrl = Uri.parse('https://registry.test/registry.json');

RegistryEntry _entry({
  String pluginId = 'com.test.alpha',
  String name = 'Alpha',
  String summary = 'Alat alpha untuk teks.',
  RegistryEntryStatus status = RegistryEntryStatus.active,
  SemanticVersion? minAppVersion,
  Set<PluginPermission> permissions = const <PluginPermission>{
    PluginPermission.cpu,
  },
}) {
  return RegistryEntry(
    pluginId: pluginId,
    version: SemanticVersion.parse('1.2.0'),
    name: name,
    summary: summary,
    description: 'Deskripsi $name.',
    author: 'Bufferite',
    license: 'MIT',
    tier: RuntimeTier.lua,
    minAppVersion: minAppVersion ?? SemanticVersion.parse('1.0.0'),
    permissions: permissions,
    sizeBytes: 2048,
    sha256: List<String>.filled(64, 'a').join(),
    downloadUrl: 'packages/$pluginId/1.2.0/pack.berp',
    publishedAt: DateTime.utc(2026, 11, 20, 10),
    status: status,
    tags: const <String>['teks'],
  );
}

RegistrySnapshot _snapshot({
  List<RegistryEntry>? entries,
  bool fromCache = true,
  bool offline = false,
  bool stale = false,
}) {
  return RegistrySnapshot(
    index: RegistryIndex(
      sequence: 3,
      generatedAt: DateTime.utc(2026, 11, 20, 10),
      allowedHosts: const <String>['registry.test'],
      plugins: entries ?? <RegistryEntry>[_entry()],
    ),
    sourceUrl: _sourceUrl,
    fetchedAt: DateTime.utc(2026, 11, 20, 10, 30),
    fromCache: fromCache,
    stale: stale,
    offline: offline,
  );
}

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController({AppSettings? initial})
    : initial = initial ?? AppSettings.defaults;

  final AppSettings initial;
  bool? consent;

  @override
  Future<AppSettings> build() async => initial;

  @override
  Future<void> setRegistryConsent(bool enabled) async {
    consent = enabled;
    final current = state.asData?.value ?? initial;
    state = AsyncData(current.copyWith(registryConsent: enabled));
  }
}

class _FakeCatalogController extends RegistryCatalogController {
  _FakeCatalogController(this.snapshot);

  final RegistrySnapshot? snapshot;
  int refreshes = 0;

  @override
  Future<RegistrySnapshot?> build() async => snapshot;

  @override
  Future<void> refresh() async {
    refreshes++;
  }
}

class _FakeInstallService extends RegistryInstallService {
  _FakeInstallService(super.ref);

  int calls = 0;

  @override
  Future<InstalledPlugin> install({
    required RegistryEntry entry,
    required RegistrySnapshot snapshot,
  }) async {
    calls++;
    return InstalledPlugin(
      manifest: PluginManifest.fromJson(
        validManifestJson(
          pluginId: entry.pluginId,
          version: entry.version.toString(),
        ),
      ),
      source: PluginSource.registry,
      installedAt: DateTime.utc(2026, 11, 20, 12),
      verified: true,
    );
  }
}

void main() {
  late _FakeSettingsController settingsController;
  late _FakeCatalogController catalogController;
  late _FakeInstallService installService;

  Widget host(
    Widget home, {
    required RegistrySnapshot snapshot,
    bool consent = true,
  }) {
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() {
          settingsController = _FakeSettingsController(
            initial: AppSettings(registryConsent: consent),
          );
          return settingsController;
        }),
        installedPluginsProvider.overrideWith(
          (ref) async => <InstalledPlugin>[],
        ),
        appVersionProvider.overrideWithValue(SemanticVersion.parse('1.0.0')),
        registryCatalogProvider.overrideWith(() {
          catalogController = _FakeCatalogController(snapshot);
          return catalogController;
        }),
        registryInstallServiceProvider.overrideWith((ref) {
          installService = _FakeInstallService(ref);
          return installService;
        }),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: home),
    );
  }

  testWidgets('katalog menampilkan entri dan pencarian menyaring nama', (
    tester,
  ) async {
    final snapshot = _snapshot(
      entries: <RegistryEntry>[
        _entry(),
        _entry(
          pluginId: 'com.test.beta',
          name: 'Beta',
          summary: 'Alat beta untuk gambar.',
        ),
      ],
    );
    await tester.pumpWidget(
      host(const RegistryCatalogScreen(), snapshot: snapshot),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('aktif'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pump();

    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('banner cache offline tampil saat registry gagal dijangkau', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const RegistryCatalogScreen(),
        snapshot: _snapshot(offline: true, stale: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Menampilkan cache terverifikasi karena registry tidak dapat '
        'dijangkau.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('konsen diminta sekali dan refresh dipanggil setelah setuju', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const RegistryCatalogScreen(),
        snapshot: _snapshot(),
        consent: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Akses katalog plugin?'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Izinkan akses'),
    );
    await tester.pumpAndSettle();

    expect(settingsController.consent, isTrue);
    expect(catalogController.refreshes, 1);
  });

  testWidgets('detail menampilkan izin dan memperbarui plugin terpasang', (
    tester,
  ) async {
    final entry = _entry();
    final snapshot = _snapshot(entries: <RegistryEntry>[entry]);
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        RegistryDetailScreen(entry: entry, snapshot: snapshot),
        snapshot: snapshot,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.2.0'), findsOneWidget);
    expect(find.text('2048 byte'), findsOneWidget);
    expect(find.text('cpu'), findsOneWidget);
    expect(find.text('signature terverifikasi'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Instal'));
    await tester.pumpAndSettle();
    expect(find.text('Instal plugin dari registry?'), findsOneWidget);

    await tester.tap(find.text('Instal').last);
    await tester.pumpAndSettle();

    expect(installService.calls, 1);
    expect(find.textContaining('terpasang dan terverifikasi'), findsOneWidget);
  });

  testWidgets('detail menonaktifkan instalasi untuk rilis revoked', (
    tester,
  ) async {
    final entry = _entry(status: RegistryEntryStatus.revoked);
    final snapshot = _snapshot(entries: <RegistryEntry>[entry]);
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        RegistryDetailScreen(entry: entry, snapshot: snapshot),
        snapshot: snapshot,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rilis ini tidak dapat diinstal.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Instal'),
    );
    expect(button.onPressed, isNull);
  });
}
