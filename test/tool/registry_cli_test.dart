import 'dart:convert';
import 'dart:io';

import 'package:bufferite/core/registry/registry_index.dart';
import 'package:bufferite/core/registry/registry_signature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/registry_cli.dart';
import '../core/support/plugin_fixtures.dart';

Future<(int, String, String)> _run(List<String> args) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runRegistryCli(args, out: out, err: err);
  return (code, out.toString(), err.toString());
}

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('bufferite_registry_cli_');
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  String path(String name) => '${temp.path}/$name';

  test('keygen menulis private key dan trust store', () async {
    final result = await _run(<String>[
      'keygen',
      '--key-id',
      'test-key',
      '--out',
      path('key.json'),
      '--public-out',
      path('keys.json'),
      '--usage',
      'both',
    ]);

    expect(result.$1, 0, reason: result.$3);
    final privateKey = RegistryPrivateKey.fromBytes(
      File(path('key.json')).readAsBytesSync(),
    );
    expect(privateKey.keyId, 'test-key');
    expect(privateKey.seed, hasLength(32));

    final trustStore = RegistryTrustStore.fromBytes(
      File(path('keys.json')).readAsBytesSync(),
    );
    expect(trustStore.keys.single.keyId, 'test-key');
    expect(trustStore.keys.single.usage, 'both');
    expect(trustStore.keys.single.isActive, isTrue);

    final exists = await _run(<String>[
      'keygen',
      '--key-id',
      'test-key',
      '--out',
      path('key.json'),
    ]);
    expect(exists.$1, 1);
    expect(exists.$3, contains('sudah ada'));

    final forced = await _run(<String>[
      'keygen',
      '--key-id',
      'test-key',
      '--out',
      path('key.json'),
      '--force',
    ]);
    expect(forced.$1, 0, reason: forced.$3);

    final publicExists = await _run(<String>[
      'keygen',
      '--key-id',
      'test-key',
      '--out',
      path('other.json'),
      '--public-out',
      path('keys.json'),
    ]);
    expect(publicExists.$1, 1);
    expect(publicExists.$3, contains('sudah ada'));
  });

  test('alur package -> build-index -> sign -> verify', () async {
    final packagePath = path('packages/com.test.pack/1.0.0/pack-1.0.0.berp');
    final packageFile = File(packagePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(buildPackageZip());
    final sourceFile = File(path('registry-source.json'))
      ..writeAsStringSync(
        jsonEncode(<String, Object?>{
          'baseUrl': 'https://registry.test/registry/v1/registry.json',
          'allowedHosts': <Object?>['registry.test'],
          'generatedAt': '2026-11-20T12:00:00Z',
          'packages': <Object?>[
            <String, Object?>{
              'path': 'packages/com.test.pack/1.0.0/pack-1.0.0.berp',
              'summary': 'Paket uji CLI.',
              'publishedAt': '2026-11-20T10:00:00Z',
            },
          ],
        }),
      );
    final keyFile = File(path('key.json'));
    final keysFile = File(path('keys.json'));
    expect(
      (await _run(<String>[
        'keygen',
        '--key-id',
        'package-key',
        '--out',
        keyFile.path,
        '--public-out',
        keysFile.path,
      ])).$1,
      0,
    );

    final signed = await _run(<String>[
      'sign',
      'package',
      '--in',
      packageFile.path,
      '--out',
      '$packagePath.sig',
      '--key',
      keyFile.path,
    ]);
    expect(signed.$1, 0, reason: signed.$3);
    expect(File('$packagePath.sig').existsSync(), isTrue);

    final built = await _run(<String>[
      'build-index',
      '--source',
      sourceFile.path,
      '--out',
      path('registry.json'),
      '--sequence',
      '3',
      '--generated-at',
      '2026-11-20T12:00:00Z',
    ]);
    expect(built.$1, 0, reason: built.$3);
    final index = RegistryIndex.fromBytes(
      File(path('registry.json')).readAsBytesSync(),
    );
    expect(index.sequence, 3);
    expect(index.plugins, hasLength(1));
    final entry = index.plugins.single;
    expect(entry.sha256, hasLength(64));
    expect(entry.downloadUrl, 'packages/com.test.pack/1.0.0/pack-1.0.0.berp');

    final signedIndex = await _run(<String>[
      'sign',
      'index',
      '--in',
      path('registry.json'),
      '--out',
      path('registry.json.sig'),
      '--key',
      keyFile.path,
    ]);
    expect(signedIndex.$1, 0, reason: signedIndex.$3);

    final validatedPackage = await _run(<String>[
      'validate',
      'package',
      '--in',
      packageFile.path,
      '--sig',
      '$packagePath.sig',
      '--keyring',
      keysFile.path,
    ]);
    expect(validatedPackage.$1, 0, reason: validatedPackage.$3);
    expect(validatedPackage.$2, contains('signature valid'));

    final validatedIndex = await _run(<String>[
      'validate',
      'index',
      '--in',
      path('registry.json'),
      '--base-url',
      'https://registry.test/registry/v1/registry.json',
    ]);
    expect(validatedIndex.$1, 0, reason: validatedIndex.$3);
    expect(validatedIndex.$2, contains('sequence: 3'));

    final verifiedPackage = await _run(<String>[
      'verify',
      'package',
      '--in',
      packageFile.path,
      '--sig',
      '$packagePath.sig',
      '--keyring',
      keysFile.path,
    ]);
    expect(verifiedPackage.$1, 0, reason: verifiedPackage.$3);

    final verifiedIndex = await _run(<String>[
      'verify',
      'index',
      '--in',
      path('registry.json'),
      '--sig',
      path('registry.json.sig'),
      '--keyring',
      keysFile.path,
      '--base-url',
      'https://registry.test/registry/v1/registry.json',
    ]);
    expect(verifiedIndex.$1, 0, reason: verifiedIndex.$3);
    expect(verifiedIndex.$2, contains('signature valid'));

    File(
      path('registry.json'),
    ).writeAsStringSync('${File(path('registry.json')).readAsStringSync()} ');
    final tampered = await _run(<String>[
      'verify',
      'index',
      '--in',
      path('registry.json'),
      '--sig',
      path('registry.json.sig'),
      '--keyring',
      keysFile.path,
    ]);
    expect(tampered.$1, 1);
    expect(tampered.$3, contains('registry.signature_invalid'));
  });

  test('opsi wajib yang hilang menghasilkan exit code 1', () async {
    final result = await _run(<String>['sign', 'index', '--in', 'x']);
    expect(result.$1, 1);
    expect(result.$3, contains('--out'));
  });

  test('opsi tidak dikenal menghasilkan exit code 2', () async {
    final result = await _run(<String>[
      'verify',
      'index',
      '--in',
      'a',
      '--sig',
      'b',
      '--keyring',
      'c',
      '--keyringg',
      'd',
    ]);
    expect(result.$1, 2);
    expect(result.$3, contains('Opsi tidak dikenal'));
  });
}
