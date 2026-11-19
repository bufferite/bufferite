import 'dart:convert';
import 'dart:io';

import 'package:bufferite/core/registry/registry_index.dart';
import 'package:bufferite/core/registry/registry_signature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/registry/registry_builder.dart';
import '../core/support/plugin_fixtures.dart';

void main() {
  late Directory temp;
  late GeneratedRegistryKey key;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('bufferite_registry_build_');
    key = await generateRegistryKey(keyId: 'package-2026');
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test(
    'build index deterministik, menaikkan sequence, dan memverifikasi sig',
    () async {
      final package = await _writePackage(
        temp,
        key: key,
        pluginId: 'com.test.pack',
        version: '1.2.0',
        sign: true,
      );
      final source = File('${temp.path}/registry-source.json')
        ..writeAsStringSync(
          jsonEncode(<String, Object?>{
            'baseUrl': 'https://registry.test/registry/v1/registry.json',
            'allowedHosts': <Object?>['registry.test'],
            'generatedAt': '2026-11-20T12:00:00Z',
            'packages': <Object?>[
              <String, Object?>{
                'path': package.relativePath,
                'summary': 'Paket uji.',
                'publishedAt': '2026-11-20T10:00:00Z',
                'tags': <Object?>['test', 'encoding'],
              },
            ],
          }),
        );
      final trustStore = RegistryTrustStore(<RegistryTrustedKey>[
        RegistryTrustedKey(
          keyId: key.privateKey.keyId,
          usage: 'both',
          publicKey: key.publicKey,
          status: 'active',
          createdAt: '2026-11-20',
        ),
      ]);

      final first = await const RegistryIndexBuilder().build(
        sourceFile: source,
        sequence: 7,
        generatedAt: DateTime.utc(2026, 11, 20, 12),
        trustStore: trustStore,
      );
      final second = await const RegistryIndexBuilder().build(
        sourceFile: source,
        sequence: 7,
        generatedAt: DateTime.utc(2026, 11, 20, 12),
        trustStore: trustStore,
      );
      expect(second.content, first.content);

      expect(first.index.sequence, 7);
      expect(first.index.plugins, hasLength(1));
      final entry = first.index.plugins.single;
      expect(entry.pluginId, 'com.test.pack');
      expect(entry.version.toString(), '1.2.0');
      expect(entry.summary, 'Paket uji.');
      expect(entry.downloadUrl, 'packages/com.test.pack/1.2.0/pack-1.2.0.berp');
      expect(entry.tags, <String>['encoding', 'test']);
      expect(entry.permissions.single.wireName, 'cpu');

      final base = File('${temp.path}/registry.json')
        ..writeAsStringSync(first.content);
      final next = await const RegistryIndexBuilder().build(
        sourceFile: source,
        baseIndexFile: base,
        trustStore: trustStore,
      );
      expect(next.index.sequence, 8);
      expect(next.index.generatedAt, DateTime.utc(2026, 11, 20, 12));
    },
  );

  test('menolak sequence eksplisit yang tidak lebih besar dari base', () async {
    final package = await _writePackage(
      temp,
      key: key,
      pluginId: 'com.test.pack',
      version: '1.0.0',
      sign: true,
    );
    final source = _source(
      temp,
      packages: <Map<String, Object?>>[
        <String, Object?>{
          'path': package.relativePath,
          'summary': 'Base sequence.',
          'publishedAt': '2026-11-20T10:00:00Z',
        },
      ],
    );
    final base = File('${temp.path}/registry.json')
      ..writeAsStringSync(
        RegistryIndex(
          sequence: 5,
          generatedAt: DateTime.utc(2026, 11, 20, 12),
          allowedHosts: const <String>['registry.test'],
          plugins: const <RegistryEntry>[],
        ).encode(),
      );

    await expectLater(
      const RegistryIndexBuilder().build(
        sourceFile: source,
        baseIndexFile: base,
        sequence: 5,
      ),
      throwsA(
        isA<RegistryFormatException>().having(
          (error) => error.message,
          'message',
          contains('harus lebih besar'),
        ),
      ),
    );
  });

  test('menolak source lebih dari 2000 paket', () {
    final source = _source(
      temp,
      packages: List<Map<String, Object?>>.generate(
        2001,
        (index) => <String, Object?>{
          'path': 'packages/p$index/a.berp',
          'summary': 'Paket $index.',
          'publishedAt': '2026-11-20T10:00:00Z',
        },
      ),
    );

    expect(
      () => RegistryBuildSource.fromBytes(source.readAsBytesSync()),
      throwsA(
        isA<RegistryFormatException>().having(
          (error) => error.message,
          'message',
          contains('2000'),
        ),
      ),
    );
  });

  test('menolak paket tanpa signature', () async {
    final package = await _writePackage(
      temp,
      key: key,
      pluginId: 'com.test.pack',
      version: '2.0.0',
      sign: false,
    );
    final source = _source(
      temp,
      packages: <Map<String, Object?>>[
        <String, Object?>{
          'path': package.relativePath,
          'summary': 'Tanpa signature.',
          'publishedAt': '2026-11-20T10:00:00Z',
        },
      ],
    );

    await expectLater(
      const RegistryIndexBuilder().build(sourceFile: source),
      throwsA(
        isA<RegistryFormatException>().having(
          (error) => error.message,
          'message',
          contains('Signature paket tidak ditemukan'),
        ),
      ),
    );
  });

  test('menolak pluginId source yang tidak cocok dengan manifest', () async {
    final package = await _writePackage(
      temp,
      key: key,
      pluginId: 'com.test.pack',
      version: '1.0.0',
      sign: true,
    );
    final source = _source(
      temp,
      packages: <Map<String, Object?>>[
        <String, Object?>{
          'path': package.relativePath,
          'pluginId': 'com.test.lain',
          'summary': 'Mismatch.',
          'publishedAt': '2026-11-20T10:00:00Z',
        },
      ],
    );

    await expectLater(
      const RegistryIndexBuilder().build(sourceFile: source),
      throwsA(isA<RegistryFormatException>()),
    );
  });

  test('menolak paket yang berubah setelah ditandatangani', () async {
    final package = await _writePackage(
      temp,
      key: key,
      pluginId: 'com.test.pack',
      version: '1.0.0',
      sign: true,
    );
    final source = _source(
      temp,
      packages: <Map<String, Object?>>[
        <String, Object?>{
          'path': package.relativePath,
          'summary': 'Berubah.',
          'publishedAt': '2026-11-20T10:00:00Z',
        },
      ],
    );
    final trustStore = RegistryTrustStore(<RegistryTrustedKey>[
      RegistryTrustedKey(
        keyId: key.privateKey.keyId,
        usage: 'both',
        publicKey: key.publicKey,
        status: 'active',
        createdAt: '2026-11-20',
      ),
    ]);

    package.file.writeAsBytesSync(
      buildPackageZip(
        manifest: validManifestJson(
          pluginId: 'com.test.pack',
          version: '1.0.0',
        ),
        files: const <String, String>{
          'main.lua': 'return function(input, args) return input end',
          'extra.txt': 'berubah',
        },
      ),
    );

    await expectLater(
      const RegistryIndexBuilder().build(
        sourceFile: source,
        trustStore: trustStore,
      ),
      throwsA(
        isA<RegistryFormatException>().having(
          (error) => error.code,
          'code',
          'registry.signature_invalid',
        ),
      ),
    );
  });

  test('menolak base index yang tidak ditemukan', () async {
    final source = _source(temp, packages: const <Map<String, Object?>>[]);

    await expectLater(
      const RegistryIndexBuilder().build(
        sourceFile: source,
        baseIndexFile: File('${temp.path}/tidak-ada.json'),
      ),
      throwsA(
        isA<RegistryFormatException>().having(
          (error) => error.code,
          'code',
          'registry.io',
        ),
      ),
    );
  });

  test('writeFileAtomically menimpa isi lama', () {
    final file = File('${temp.path}/output.json')..writeAsStringSync('lama');
    writeFileAtomically(file, 'baru');
    expect(file.readAsStringSync(), 'baru');
  });
}

File _source(Directory temp, {required List<Map<String, Object?>> packages}) {
  return File('${temp.path}/registry-source.json')..writeAsStringSync(
    jsonEncode(<String, Object?>{
      'baseUrl': 'https://registry.test/registry/v1/registry.json',
      'allowedHosts': <Object?>['registry.test'],
      'generatedAt': '2026-11-20T12:00:00Z',
      'packages': packages,
    }),
  );
}

final class _SignedPackage {
  const _SignedPackage({required this.file, required this.relativePath});

  final File file;
  final String relativePath;
}

Future<_SignedPackage> _writePackage(
  Directory temp, {
  required GeneratedRegistryKey key,
  required String pluginId,
  required String version,
  required bool sign,
}) async {
  final relative = 'packages/$pluginId/$version/pack-$version.berp';
  final file = File('${temp.path}/$relative')
    ..createSync(recursive: true)
    ..writeAsBytesSync(
      buildPackageZip(
        manifest: validManifestJson(pluginId: pluginId, version: version),
      ),
    );
  if (sign) {
    final signature = await signRegistryPackage(
      key: key.privateKey,
      pluginId: pluginId,
      version: version,
      bytes: file.readAsBytesSync(),
    );
    File('${file.path}.sig').writeAsStringSync(signature.encode());
  }
  return _SignedPackage(file: file, relativePath: relative);
}
