import 'dart:convert';

import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/core/plugin/semantic_version.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/plugin_fixtures.dart';

PluginManifest _manifest({String minAppVersion = '1.0.0'}) {
  return PluginManifest.fromJson(
    validManifestJson()..['minAppVersion'] = minAppVersion,
  );
}

InstalledPlugin _installed({
  bool enabled = true,
  bool verified = true,
  String minAppVersion = '1.0.0',
}) {
  return InstalledPlugin(
    manifest: _manifest(minAppVersion: minAppVersion),
    source: PluginSource.sideload,
    installedAt: DateTime.utc(2026, 11, 11, 10, 30),
    enabled: enabled,
    verified: verified,
    installPath: '/plugins/com.test.pack/1.0.0',
  );
}

void main() {
  group('InstalledPlugin', () {
    test('serialisasi JSON round-trip', () {
      final plugin = _installed();
      final parsed = InstalledPlugin.fromJson(
        jsonDecode(jsonEncode(plugin.toJson())) as Map<String, Object?>,
      );

      expect(parsed.pluginId, 'com.test.pack');
      expect(parsed.version.toString(), '1.0.0');
      expect(parsed.source, PluginSource.sideload);
      expect(parsed.installedAt, DateTime.utc(2026, 11, 11, 10, 30));
      expect(parsed.enabled, isTrue);
      expect(parsed.verified, isTrue);
      expect(parsed.installPath, '/plugins/com.test.pack/1.0.0');
    });

    test('default enabled/verified saat impor metadata lama', () {
      final json = _installed().toJson()
        ..remove('enabled')
        ..remove('verified');
      final parsed = InstalledPlugin.fromJson(json);
      expect(parsed.enabled, isTrue);
      expect(parsed.verified, isFalse);
    });

    test('status mengikuti enabled, kompatibilitas, dan verifikasi', () {
      final app = SemanticVersion.parse('1.0.0');
      expect(_installed().statusFor(app), PluginStatus.active);
      expect(_installed(enabled: false).statusFor(app), PluginStatus.disabled);
      expect(
        _installed(verified: false).statusFor(app),
        PluginStatus.unverified,
      );
      expect(
        _installed(minAppVersion: '2.0.0').statusFor(app),
        PluginStatus.incompatible,
      );
      expect(_installed(minAppVersion: '2.0.0').isCompatibleWith(app), isFalse);
    });

    test('copyWith mengubah status tanpa kehilangan metadata', () {
      final disabled = _installed().copyWith(enabled: false);
      expect(disabled.enabled, isFalse);
      expect(disabled.pluginId, 'com.test.pack');
      expect(disabled.installPath, '/plugins/com.test.pack/1.0.0');
    });

    test('menolak metadata invalid', () {
      final base = _installed().toJson();
      expect(
        () => InstalledPlugin.fromJson(base..['source'] = 'unknown'),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.source_invalid',
          ),
        ),
      );
      expect(
        () => InstalledPlugin.fromJson(
          _installed().toJson()..['installedAt'] = 'not-a-date',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.installed_invalid',
          ),
        ),
      );
      expect(
        () => InstalledPlugin.fromJson(
          _installed().toJson()..['enabled'] = 'yes',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.installed_invalid',
          ),
        ),
      );
      expect(
        () => InstalledPlugin.fromJson(
          _installed().toJson()..['manifest'] = 'not-a-map',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.installed_invalid',
          ),
        ),
      );
    });
  });
}
