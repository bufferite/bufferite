import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/registry/registry_cache.dart';
import 'package:bufferite/core/registry/registry_cache_store.dart';
import 'package:bufferite/core/registry/registry_client.dart';
import 'package:bufferite/core/registry/registry_error.dart';
import 'package:bufferite/core/registry/registry_index.dart';
import 'package:bufferite/core/registry/registry_signature.dart';
import 'package:bufferite/core/registry/registry_transport.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _SignedIndex = ({Uint8List bytes, Uint8List signature});

final Uri _indexUri = Uri.parse('https://registry.test/registry.json');
final Uri _signatureUri = Uri.parse('https://registry.test/registry.json.sig');

late RegistryPrivateKey _key;
late RegistryTrustStore _trustStore;

void main() {
  setUpAll(() async {
    final generated = await generateRegistryKey(keyId: 'index-test');
    _key = generated.privateKey;
    _trustStore = RegistryTrustStore(<RegistryTrustedKey>[
      RegistryTrustedKey(
        keyId: generated.privateKey.keyId,
        usage: 'index',
        publicKey: generated.publicKey,
        status: 'active',
        createdAt: '2026-11-20',
      ),
    ]);
  });

  test('refresh memverifikasi signature, mengirim header, dan cache', () async {
    final signed = await _signedIndex();
    final transport = _FakeTransport(_responses(signed));
    final store = _MemoryCacheStore();
    final client = _client(transport: transport, store: store);

    final snapshot = await client.refresh();

    expect(snapshot.index.sequence, 1);
    expect(snapshot.fromCache, isFalse);
    expect(snapshot.stale, isFalse);
    expect(snapshot.offline, isFalse);
    expect(transport.requests, <Uri>[_indexUri, _signatureUri]);
    expect(transport.requestHeaders.first['User-Agent'], 'Bufferite/test');
    expect(transport.requestHeaders.first['Accept'], 'application/json');
    expect(transport.maxBytesRequests.first, registryMaxIndexBytes);
    expect(transport.maxBytesRequests.last, registryMaxSignatureBytes);
    expect(store.writes, 1);
    expect(store.cache, isNotNull);

    final cached = await client.loadCached();
    expect(cached, isNotNull);
    expect(cached!.fromCache, isTrue);
    expect(cached.index.sequence, 1);
    expect(cached.stale, isFalse);
  });

  test('loadCached memverifikasi ulang signature', () async {
    final signed = await _signedIndex();
    final store = _MemoryCacheStore()
      ..cache = RegistryCache(
        indexBytes: Uint8List.fromList(<int>[...signed.bytes, 0x20]),
        signatureBytes: signed.signature,
        fetchedAt: DateTime.utc(2026, 11, 20, 12),
        sourceUrl: _indexUri,
      );
    final client = _client(
      transport: _FakeTransport(<String, RegistryResponse>{}),
      store: store,
    );

    await expectLater(
      client.loadCached(),
      throwsA(_formatError('registry.signature_invalid')),
    );
  });

  test('signature salah tidak menulis cache', () async {
    final signed = await _signedIndex();
    final tampered = Uint8List.fromList(<int>[...signed.bytes, 0x20]);
    final transport = _FakeTransport(<String, RegistryResponse>{
      _indexUri.toString(): RegistryResponse(
        bytes: tampered,
        finalUrl: _indexUri,
      ),
      _signatureUri.toString(): RegistryResponse(
        bytes: signed.signature,
        finalUrl: _signatureUri,
      ),
    });
    final store = _MemoryCacheStore();
    final client = _client(transport: transport, store: store);

    await expectLater(
      client.refresh(),
      throwsA(_formatError('registry.signature_invalid')),
    );
    expect(store.cache, isNull);
  });

  test('replay ditolak dan cache lama dipertahankan', () async {
    final transport = _FakeTransport(
      _responses(await _signedIndex(sequence: 2)),
    );
    final store = _MemoryCacheStore();
    final client = _client(transport: transport, store: store);
    await client.refresh();

    transport.responses
      ..clear()
      ..addAll(_responses(await _signedIndex(sequence: 1)));

    await expectLater(
      client.refresh(),
      throwsA(_clientError('registry.replay')),
    );
    final cached = await client.loadCached();
    expect(cached!.index.sequence, 2);
    expect(store.writes, 1);
  });

  test('offline memakai cache terverifikasi', () async {
    final transport = _FakeTransport(_responses(await _signedIndex()));
    final store = _MemoryCacheStore();
    final client = _client(transport: transport, store: store);
    await client.refresh();

    transport.error = const RegistryClientException(
      'registry.offline',
      'offline',
    );
    final snapshot = await client.loadWithFallback();

    expect(snapshot.fromCache, isTrue);
    expect(snapshot.offline, isTrue);
    expect(snapshot.index.sequence, 1);
  });

  test('offline tanpa cache melempar error', () async {
    final transport = _FakeTransport(<String, RegistryResponse>{})
      ..error = const RegistryClientException('registry.offline', 'offline');
    final client = _client(transport: transport, store: _MemoryCacheStore());

    await expectLater(
      client.loadWithFallback(),
      throwsA(_clientError('registry.offline')),
    );
  });

  test('HTTP error tanpa cache diteruskan', () async {
    final client = _client(
      transport: _FakeTransport(<String, RegistryResponse>{}),
      store: _MemoryCacheStore(),
    );

    await expectLater(client.refresh(), throwsA(_clientError('registry.http')));
  });

  test('indeks kebesaran ditolak sebelum signature diunduh', () async {
    final transport = _FakeTransport(<String, RegistryResponse>{
      _indexUri.toString(): RegistryResponse(
        bytes: Uint8List(registryMaxIndexBytes + 1),
        finalUrl: _indexUri,
      ),
    });
    final client = _client(transport: transport, store: _MemoryCacheStore());

    await expectLater(
      client.refresh(),
      throwsA(_clientError('registry.too_large')),
    );
    expect(transport.requests, hasLength(1));
  });

  test('indeks tidak valid ditolak setelah signature valid', () async {
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(<String, Object?>{'registryVersion': 1})),
    );
    final signature = await signRegistryIndex(key: _key, bytes: bytes);
    final transport = _FakeTransport(<String, RegistryResponse>{
      _indexUri.toString(): RegistryResponse(bytes: bytes, finalUrl: _indexUri),
      _signatureUri.toString(): RegistryResponse(
        bytes: Uint8List.fromList(utf8.encode(signature.encode())),
        finalUrl: _signatureUri,
      ),
    });
    final store = _MemoryCacheStore();
    final client = _client(transport: transport, store: store);

    await expectLater(
      client.refresh(),
      throwsA(_formatError('registry.schema')),
    );
    expect(store.cache, isNull);
  });

  test('registryVersion lebih tinggi meminta update aplikasi', () async {
    final signed = await _signedIndex(version: 2);
    final client = _client(
      transport: _FakeTransport(_responses(signed)),
      store: _MemoryCacheStore(),
    );

    await expectLater(
      client.refresh(),
      throwsA(_formatError('registry.app_too_old')),
    );
  });

  test('host final redirect harus ada di allowedHosts', () async {
    final signed = await _signedIndex();
    final finalUrl = Uri.parse('https://evil.test/registry.json');
    final transport = _FakeTransport(<String, RegistryResponse>{
      _indexUri.toString(): RegistryResponse(
        bytes: signed.bytes,
        finalUrl: finalUrl,
      ),
      'https://evil.test/registry.json.sig': RegistryResponse(
        bytes: signed.signature,
        finalUrl: Uri.parse('https://evil.test/registry.json.sig'),
      ),
    });
    final client = _client(transport: transport, store: _MemoryCacheStore());

    await expectLater(
      client.refresh(),
      throwsA(_formatError('registry.schema')),
    );
  });

  test('cache lebih dari 24 jam ditandai basi', () async {
    var now = DateTime.utc(2026, 11, 20, 12);
    final transport = _FakeTransport(_responses(await _signedIndex()));
    final store = _MemoryCacheStore();
    final client = _client(
      transport: transport,
      store: store,
      clock: () => now,
    );
    await client.refresh();

    now = now.add(const Duration(hours: 25));
    final cached = await client.loadCached();
    expect(cached!.stale, isTrue);
  });

  test('FileRegistryCacheStore round-trip dan menolak cache korup', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bufferite_registry_cache_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FileRegistryCacheStore(directory: () async => directory);
    final cache = RegistryCache(
      indexBytes: Uint8List.fromList(<int>[1, 2, 3]),
      signatureBytes: Uint8List.fromList(<int>[4, 5]),
      fetchedAt: DateTime.utc(2026, 11, 20, 12),
      sourceUrl: _indexUri,
    );

    await store.write(cache);
    final read = await store.read();
    expect(read!.indexBytes, cache.indexBytes);
    expect(read.signatureBytes, cache.signatureBytes);
    expect(read.fetchedAt, cache.fetchedAt);
    expect(read.sourceUrl, cache.sourceUrl);

    await store.write(
      RegistryCache(
        indexBytes: Uint8List.fromList(<int>[9, 9]),
        signatureBytes: Uint8List.fromList(<int>[8]),
        fetchedAt: DateTime.utc(2026, 11, 20, 13),
        sourceUrl: _indexUri,
      ),
    );
    final updated = await store.read();
    expect(updated!.indexBytes, <int>[9, 9]);
    expect(updated.fetchedAt, DateTime.utc(2026, 11, 20, 13));

    final file = File(
      '${directory.path}${Platform.pathSeparator}registry_cache.json',
    );
    await file.writeAsString('{');
    await expectLater(
      store.read(),
      throwsA(_clientError('registry.cache_corrupt')),
    );

    await store.clear();
    expect(await store.read(), isNull);
  });
}

RegistryClient _client({
  required _FakeTransport transport,
  required _MemoryCacheStore store,
  DateTime Function()? clock,
}) {
  return RegistryClient(
    trustStore: _trustStore,
    transport: transport,
    cacheStore: store,
    userAgent: 'Bufferite/test',
    indexUrl: _indexUri,
    clock: clock ?? () => DateTime.utc(2026, 11, 20, 12),
  );
}

Future<_SignedIndex> _signedIndex({int sequence = 1, int version = 1}) async {
  final bytes = Uint8List.fromList(
    utf8.encode(jsonEncode(_indexJson(sequence: sequence, version: version))),
  );
  final signature = await signRegistryIndex(key: _key, bytes: bytes);
  return (
    bytes: bytes,
    signature: Uint8List.fromList(utf8.encode(signature.encode())),
  );
}

Map<String, Object?> _indexJson({required int sequence, required int version}) {
  return <String, Object?>{
    'registryVersion': version,
    'sequence': sequence,
    'generatedAt': '2026-11-20T12:00:00Z',
    'allowedHosts': <String>['registry.test'],
    'plugins': <Object?>[_entryJson()],
  };
}

Map<String, Object?> _entryJson() {
  return <String, Object?>{
    'pluginId': 'com.test.pack',
    'version': '1.0.0',
    'name': 'Test Pack',
    'summary': 'Ringkasan pendek.',
    'tier': 'lua',
    'minAppVersion': '1.0.0',
    'permissions': <Object?>['cpu'],
    'sizeBytes': 100,
    'sha256': 'a' * 64,
    'downloadUrl': 'packages/com.test.pack/1.0.0/pack-1.0.0.berp',
    'publishedAt': '2026-11-20T10:00:00Z',
    'status': 'active',
  };
}

Map<String, RegistryResponse> _responses(_SignedIndex signed, {Uri? finalUrl}) {
  final resolved = finalUrl ?? _indexUri;
  final signatureUrl = _signatureUrl(resolved);
  return <String, RegistryResponse>{
    _indexUri.toString(): RegistryResponse(
      bytes: signed.bytes,
      finalUrl: resolved,
    ),
    signatureUrl.toString(): RegistryResponse(
      bytes: signed.signature,
      finalUrl: signatureUrl,
    ),
  };
}

Uri _signatureUrl(Uri indexUrl) {
  return Uri(
    scheme: indexUrl.scheme,
    host: indexUrl.host,
    port: indexUrl.hasPort ? indexUrl.port : null,
    path: '${indexUrl.path}.sig',
  );
}

Matcher _clientError(String code) {
  return isA<RegistryClientException>().having(
    (error) => error.code,
    'code',
    code,
  );
}

Matcher _formatError(String code) {
  return isA<RegistryFormatException>().having(
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
  final List<Duration> timeouts = <Duration>[];
  RegistryClientException? error;

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
    timeouts.add(timeout);

    final failure = error;
    if (failure != null) {
      throw failure;
    }
    final response = responses[url.toString()];
    if (response == null) {
      throw RegistryClientException(
        'registry.http',
        'Registry mengembalikan HTTP 404.',
        <String, Object?>{'status': 404, 'url': url.toString()},
      );
    }
    return response;
  }
}

final class _MemoryCacheStore implements RegistryCacheStore {
  RegistryCache? cache;
  int writes = 0;

  @override
  Future<RegistryCache?> read() async => cache;

  @override
  Future<void> write(RegistryCache value) async {
    cache = value;
    writes++;
  }

  @override
  Future<void> clear() async {
    cache = null;
  }
}
