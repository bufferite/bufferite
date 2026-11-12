import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/core/plugin/semantic_version.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/plugins/plugin_manager_page.dart';
import 'package:bufferite/features/plugins/plugin_providers.dart';
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

Widget _host(List<InstalledPlugin> plugins) {
  return ProviderScope(
    overrides: [
      installedPluginsProvider.overrideWith((ref) => plugins),
      appVersionProvider.overrideWithValue(SemanticVersion.parse('1.0.0')),
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

  testWidgets('plugin nonaktif menampilkan badge nonaktif', (tester) async {
    await tester.pumpWidget(_host(<InstalledPlugin>[_plugin(enabled: false)]));
    await tester.pump();

    expect(find.text('nonaktif'), findsOneWidget);
  });
}
