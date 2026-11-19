import 'dart:convert';
import 'dart:typed_data';

import 'package:bufferite/core/registry/registry_error.dart';
import 'package:bufferite/core/registry/registry_index.dart';
import 'package:bufferite/core/registry/registry_installer.dart';
import 'package:bufferite/core/registry/registry_signature.dart';
import 'package:bufferite/core/registry/registry_transport.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/plugin_fixtures.dart';

final Uri _indexUri = Uri.parse('https://registry.test/registry.json');

late RegistryPrivateKey _key;
late RegistryTrustStore _trustStore;

void main() {
  setUpAll(() async {
    final generated = await generateRegistryKey(keyId: 'package-test');
    _key = generated.privateKey;
    _trustStore = RegistryTrustStore(<RegistryTrustedKey>[
      RegistryTrustedKey(
        keyId: generated.privateKey.keyId,
        usage: 'package',
        publicKey: generated.publicKey,
        status: 'active',
        createdAt: '2026-11-20',
      ),
    ]);
  });

  test('paket valid lolos hash, signature, dan pencocokan manifest', () async {
    final bytes = buildPackageZip();
    final digest = sha256.convert(bytes).toString();
    final index = _index(sizeBytes: bytes.length, sha256: digest);
    final entry = index.plugins.single;
    final signature = await signRegistryPackage(
      key: _key,
      pluginId: entry.pluginId,
      version: entry.version.toString(),
      bytes: bytes,
    );
    final transport = _FakeTransport(<String, RegistryResponse>{
      _downloadUrl(entry): RegistryResponse(
        bytes: bytes,
        finalUrl: Uri.parse(_downloadUrl(entry)),
      ),
      _signatureUrl(entry): RegistryResponse(
        bytes: Uint8List.fromList(utf8.encode(signature.encode())),
        finalUrl: Uri.parse(_signatureUrl(entry)),
      ),
    });
    final installer = RegistryInstaller(
      transport: transport,
      trustStore: _trustStore,
      userAgent: 'Bufferite/test',
    );

    final verified = await installer.downloadAndVerify(
      entry: entry,
      index: index,
      indexSourceUrl: _indexUri,
    );

    expect(verified.package.manifest.pluginId, 'com.test.pack');
    expect(verified.sha256, digest);
    expect(verified.keyId, _key.keyId);
    expect(transport.requests, <Uri>[
      Uri.parse(_downloadUrl(entry)),
      Uri.parse(_signatureUrl(entry)),
    ]);
    expect(
      transport.requestHeaders.first['User-Agent'],
      'Bufferite/test',
    );
    expect(
      transport.requestHeaders.first['Accept'],
      'application/octet-stream',
    );
    expect(transport.maxBytesRequests.first, bytes.length);
    expect(transport.maxBytesRequests.last, registryMaxSignatureBytes);
  });

  test('ukuran tidak sesuai indeks ditolak', () async {
    final bytes = buildPackageZip();
    final index = _index(
      sizeBytes: bytes.length + 1,
      sha256: sha256.convert(bytes).toString(),
    );
    final entry = index.plugins.single;
    final transport = _FakeTransport(<String, RegistryResponse>{
      _downloadUrl(entry): RegistryResponse(
        bytes: bytes,
        finalUrl: Uri.parse(_downloadUrl(entry)),
      ),
    });
    final installer = RegistryInstaller(
      transport: transport,
      trustStore: _trustStore,
      userAgent: 'Bufferite/test',
    );

    await expectLater(
      installer.downloadAndVerify(
        entry: entry,
        index: index,
        indexSourceUrl: _indexUri,
      ),
      throwsA(_formatError('registry.download_failed')),
    );
    expect(transport.requests, hasLength(1));
  });

  test('hash tidak cocok ditolak sebelum signature diunduh', () async {
    final bytes = buildPackageZip();
    final index = _index(sizeBytes: bytes.length, sha256: 'a' * 64);
    final entry = index.plugins.single;
    final transport = _FakeTransport(<String, RegistryResponse>{
      _downloadUrl(entry): RegistryResponse(
        bytes: bytes,
        finalUrl: Uri.parse(_downloadUrl(entry)),
      ),
    });
    final installer = RegistryInstaller(
      transport: transport,
      trustStore: _trustStore,
      userAgent: 'Bufferite/test',
    );

    await expectLater(
      installer.downloadAndVerify(
        entry: entry,
        index: index,
        indexSourceUrl: _indexUri,
      ),
      throwsA(_formatError('registry.hash_mismatch')),
    );
    expect(transport.requests, hasLength(1));
  });

  test('signature paket salah ditolak', () async {
    final bytes = buildPackageZip();
    final index = _index(
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    );
    final entry = index.plugins.single;
    final signature = await signRegistryPackage(
      key: _key,
      pluginId: entry.pluginId,
      version: '9.9.9',
      bytes: bytes,
    );
    final transport = _FakeTransport(<String, RegistryResponse>{
      _downloadUrl(entry): RegistryResponse(
        bytes: bytes,
        finalUrl: Uri.parse(_downloadUrl(entry)),
      ),
      _signatureUrl(entry): RegistryResponse(
        bytes: Uint8List.fromList(utf8.encode(signature.encode())),
        finalUrl: Uri.parse(_signatureUrl(entry)),
      ),
    });
    final installer = RegistryInstaller(
      transport: transport,
      trustStore: _trustStore,
      userAgent: 'Bufferite/test',
    );

    await expectLater(
      installer.downloadAndVerify(
        entry: entry,
        index: index,
        indexSourceUrl: _indexUri,
      ),
      throwsA(_formatError('registry.package_signature_invalid')),
    );
  });

  test('manifest tidak cocok dengan indeks ditolak', () async {
    final bytes = buildPackageZip(
      manifest: validManifestJson(pluginId: 'com.test.other'),
    );
    final digest = sha256.convert(bytes).toString();
    final index = _index(sizeBytes: bytes.length, sha256: digest);
    final entry = index.plugins.single;
    final signature = await signRegistryPackage(
      key: _key,
      pluginId: entry.pluginId,
      version: entry.version.toString(),
      bytes: bytes,
    );
    final transport = _FakeTransport(<String, RegistryResponse>{
      _downloadUrl(entry): RegistryResponse(
        bytes: bytes,
        finalUrl: Uri.parse(_downloadUrl(entry)),
      ),
      _signatureUrl(entry): RegistryResponse(
        bytes: Uint8List.fromList(utf8.encode(signature.encode())),
        finalUrl: Uri.parse(_signatureUrl(entry)),
      ),
    });
    final installer = RegistryInstaller(
      transport: transport,
      trustStore: _trustStore,
      userAgent: 'Bufferite/test',
    );

    await expectLater(
      installer.downloadAndVerify(
        entry: entry,
        index: index,
        indexSourceUrl: _indexUri,
      ),
      throwsA(_formatError('registry.manifest_mismatch')),
    );
  });

  test('host paket di luar allowedHosts ditolak tanpa request', () async {
    final bytes = buildPackageZip();
    final index = _index(
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      downloadUrl: 'https://evil.test/pack.berp',
    );
    final entry = index.plugins.single;
    final transport = _FakeTransport(<String, RegistryResponse>{});
    final installer = RegistryInstaller(
      transport: transport,
      trustStore: _trustStore,
      userAgent: 'Bufferite/test',
    );

    await expectLater(
      installer.downloadAndVerify(
        entry: entry,
        index: index,
        indexSourceUrl: _indexUri,
      ),
      throwsA(_formatError('registry.schema')),
    );
    expect(transport.requests, isEmpty);
  });

  test('respons melebihi batas transport diteruskan sebagai too_large', () async {
    final bytes = buildPackageZip();
    final index = _index(
      sizeBytes: bytes.length - 1,
      sha256: sha256.convert(bytes).toString(),
    );
    final entry = index.plugins.single;
    final transport = _FakeTransport(<String, RegistryResponse>{})
      ..enforceMaxBytes = true
      ..responses[_downloadUrl(entry)] = RegistryResponse(
        bytes: bytes,
        finalUrl: Uri.parse(_downloadUrl(entry)),
      );
    final installer = RegistryInstaller(
      transport: transport,
      trustStore: _trustStore,
      userAgent: 'Bufferite/test',
    );

    await expectLater(
      installer.downloadAndVerify(
        entry: entry,
        index: index,
        indexSourceUrl: _indexUri,
      ),
      throwsA(_clientError('registry.too_large')),
    );
  });
}

RegistryIndex _index({
  required int sizeBytes,
  required String sha256,
  String downloadUrl = 'packages/com.test.pack/1.0.0/pack-1.0.0.berp',
}) {
  return RegistryIndex.parse(
    jsonEncode(<String, Object?>{
      'registryVersion': 1,
      'sequence': 1,
      'generatedAt': '2026-11-20T10:00:00Z',
      'allowedHosts': <String>['registry.test'],
      'plugins': <Object?>[
        <String, Object?>{
          'pluginId': 'com.test.pack',
          'version': '1.0.0',
          'name': 'Test Pack',
          'summary': 'Ringkasan pendek.',
          'tier': 'lua',
          'minAppVersion': '1.0.0',
          'permissions': <String>['cpu'],
          'sizeBytes': sizeBytes,
          'sha256': sha256,
          'downloadUrl': downloadUrl,
          'publishedAt': '2026-11-20T10:00:00Z',
          'status': 'active',
        },
      ],
    }),
  );
}

String _downloadUrl(RegistryEntry entry) {
  return _indexUri.resolve(entry.downloadUrl).toString();
}

String _signatureUrl(RegistryEntry entry) {
  return _indexUri.resolve(entry.effectiveSignatureUrl).toString();
}

Matcher _formatError(String code) {
  return isA<RegistryFormatException>().having(
    (error) => error.code,
    'code',
    code,
  );
}

Matcher _clientError(String code) {
  return isA<RegistryClientException>().having(
    (error) => error.code,
    'code',
    code,
  );
}

final class _FakeTransport implements RegistryTransport {
  _FakeTransport(this.responses);

  final Map<String, RegistryResponse> responses;
  final List<Uri> requests = <Uri>[];
  final List<Map<String, String>> requestHeaders = <Map<String, String>>[];
  final List<int> maxBytesRequests = <int>[];
  bool enforceMaxBytes = false;

  @override
  Future<RegistryResponse> get(
    Uri url, {
    required Map<String, String> headers,
    required int maxBytes,
    required Duration timeout,
  }) async {
    requests.add(url);
    requestHeaders.add(Map<String, String>.of(headers));
    maxBytesRequests.add(maxBytes);

    final response = responses[url.toString()];
    if (response == null) {
      throw RegistryClientException(
        'registry.http',
        'Registry mengembalikan HTTP 404.',
        <String, Object?>{'status': 404, 'url': url.toString()},
      );
    }
    if (enforceMaxBytes && response.bytes.length > maxBytes) {
      throw RegistryClientException(
        'registry.too_large',
        'Respons registry melebihi $maxBytes byte.',
        <String, Object?>{'maxBytes': maxBytes},
      );
    }
    return response;
  }
}
