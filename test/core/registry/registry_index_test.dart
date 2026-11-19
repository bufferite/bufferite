import 'dart:convert';
import 'dart:typed_data';

import 'package:bufferite/core/registry/registry_index.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _entryJson({
  String pluginId = 'com.test.pack',
  String version = '1.2.0',
  String? downloadUrl,
}) {
  return <String, Object?>{
    'pluginId': pluginId,
    'version': version,
    'name': 'Test Pack',
    'summary': 'Ringkasan pendek.',
    'tier': 'lua',
    'minAppVersion': '1.0.0',
    'permissions': <Object?>['cpu'],
    'sizeBytes': 100,
    'sha256': 'a' * 64,
    'downloadUrl':
        downloadUrl ?? 'packages/$pluginId/$version/pack-$version.berp',
    'publishedAt': '2026-11-20T10:00:00Z',
    'status': 'active',
  };
}

Map<String, Object?> _indexJson({
  int sequence = 1,
  List<Object?>? plugins,
  List<Object?>? allowedHosts,
}) {
  return <String, Object?>{
    'registryVersion': 1,
    'sequence': sequence,
    'generatedAt': '2026-11-20T12:00:00Z',
    'allowedHosts': allowedHosts ?? <Object?>['registry.test'],
    'plugins': plugins ?? <Object?>[_entryJson()],
    'fieldBaru': 'diabaikan',
  };
}

void main() {
  group('RegistryIndex', () {
    test('parse dan encode kanonik deterministik', () {
      final index = RegistryIndex.fromJson(
        _indexJson(
          plugins: <Object?>[
            _entryJson(pluginId: 'com.test.zeta'),
            _entryJson(pluginId: 'com.test.alpha', version: '2.0.0'),
            _entryJson(pluginId: 'com.test.alpha', version: '1.0.0'),
          ],
        ),
      );

      final first = index.encode();
      final second = RegistryIndex.fromBytes(utf8.encode(first)).encode();
      expect(second, first);

      final decoded = jsonDecode(first) as Map<String, Object?>;
      final plugins = decoded['plugins']! as List<Object?>;
      expect(
        plugins
            .map((item) => (item! as Map<String, Object?>)['pluginId'])
            .toList(),
        <String>['com.test.alpha', 'com.test.alpha', 'com.test.zeta'],
      );
      expect((plugins[0]! as Map<String, Object?>)['version'], '1.0.0');
    });

    test('menolak registryVersion lebih tinggi', () {
      final json = _indexJson()..['registryVersion'] = 2;
      expect(
        () => RegistryIndex.fromJson(json),
        throwsA(
          isA<RegistryFormatException>().having(
            (error) => error.code,
            'code',
            'registry.app_too_old',
          ),
        ),
      );
    });

    test('menolak sequence nol dan indeks kebesaran', () {
      expect(
        () => RegistryIndex.fromJson(_indexJson(sequence: 0)),
        throwsA(isA<RegistryFormatException>()),
      );
      expect(
        () => RegistryIndex.fromBytes(Uint8List(registryMaxIndexBytes + 1)),
        throwsA(
          isA<RegistryFormatException>().having(
            (error) => error.code,
            'code',
            'registry.too_large',
          ),
        ),
      );
    });

    test('menolak allowedHosts kosong, duplikat, dan tidak valid', () {
      for (final hosts in <List<Object?>>[
        <Object?>[],
        <Object?>['registry.test', 'registry.test'],
        <Object?>['https://registry.test'],
        <Object?>['REGISTRY.TEST'],
      ]) {
        expect(
          () => RegistryIndex.fromJson(_indexJson(allowedHosts: hosts)),
          throwsA(isA<RegistryFormatException>()),
          reason: '$hosts',
        );
      }
    });

    test('menolak entri duplikat dan field wajib tidak valid', () {
      expect(
        () => RegistryIndex.fromJson(
          _indexJson(plugins: <Object?>[_entryJson(), _entryJson()]),
        ),
        throwsA(isA<RegistryFormatException>()),
      );

      final badHash = _entryJson()..['sha256'] = 'A' * 64;
      expect(
        () => RegistryIndex.fromJson(_indexJson(plugins: <Object?>[badHash])),
        throwsA(isA<RegistryFormatException>()),
      );

      final badPermissions = _entryJson()
        ..['permissions'] = <Object?>['cpu', 'cpu'];
      expect(
        () => RegistryIndex.fromJson(
          _indexJson(plugins: <Object?>[badPermissions]),
        ),
        throwsA(isA<RegistryFormatException>()),
      );

      final badUrl = _entryJson(downloadUrl: 'http://registry.test/a.berp');
      expect(
        () => RegistryIndex.fromJson(_indexJson(plugins: <Object?>[badUrl])),
        throwsA(isA<RegistryFormatException>()),
      );

      final traversal = _entryJson(downloadUrl: '../a.berp');
      expect(
        () => RegistryIndex.fromJson(_indexJson(plugins: <Object?>[traversal])),
        throwsA(isA<RegistryFormatException>()),
      );
    });

    test('menolak tags dan permissions di luar batas', () {
      final tooManyTags = _entryJson()
        ..['tags'] = List<String>.generate(9, (index) => 'tag$index');
      expect(
        () =>
            RegistryIndex.fromJson(_indexJson(plugins: <Object?>[tooManyTags])),
        throwsA(isA<RegistryFormatException>()),
      );

      final unknownPermission = _entryJson()
        ..['permissions'] = <Object?>['cpu', 'root'];
      expect(
        () => RegistryIndex.fromJson(
          _indexJson(plugins: <Object?>[unknownPermission]),
        ),
        throwsA(isA<RegistryFormatException>()),
      );
    });

    test('validasi URL terhadap allowedHosts', () {
      final index = RegistryIndex.fromJson(
        _indexJson(
          plugins: <Object?>[
            _entryJson(downloadUrl: 'packages/a.berp'),
            _entryJson(
              pluginId: 'com.test.evil',
              downloadUrl: 'https://evil.test/a.berp',
            ),
          ],
        ),
      );

      expect(
        () => index.validateUrls(
          Uri.parse('https://registry.test/registry/v1/registry.json'),
        ),
        throwsA(
          isA<RegistryFormatException>().having(
            (error) => error.code,
            'code',
            'registry.schema',
          ),
        ),
      );
    });
  });
}
