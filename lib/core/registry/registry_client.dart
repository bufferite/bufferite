import 'dart:typed_data';

import 'registry_cache.dart';
import 'registry_error.dart';
import 'registry_index.dart';
import 'registry_signature.dart';
import 'registry_transport.dart';

/// URL kanonis registry v1 (D12/D15).
///
/// Sementara memakai domain default GitHub Pages sampai `bufferite.dev`
/// terdaftar. Ganti kembali ke `plugins.bufferite.dev` lewat rilis aplikasi.
final Uri registryIndexUrl = Uri.parse(
  'https://bufferite.github.io/plugins/registry/v1/registry.json',
);

/// TTL tampilan cache indeks.
const Duration registryCacheTtl = Duration(hours: 24);

/// Batas total unduhan indeks + signature.
const Duration registryFetchTimeout = Duration(seconds: 30);

/// Indeks yang sudah diverifikasi beserta status cache.
final class RegistrySnapshot {
  const RegistrySnapshot({
    required this.index,
    required this.sourceUrl,
    required this.fetchedAt,
    required this.fromCache,
    required this.stale,
    this.offline = false,
  });

  final RegistryIndex index;
  final Uri sourceUrl;
  final DateTime fetchedAt;
  final bool fromCache;
  final bool stale;

  /// True bila snapshot berasal dari cache karena refresh jaringan gagal.
  final bool offline;

  RegistrySnapshot asOffline() {
    return RegistrySnapshot(
      index: index,
      sourceUrl: sourceUrl,
      fetchedAt: fetchedAt,
      fromCache: fromCache,
      stale: stale,
      offline: true,
    );
  }
}

/// Client registry read-only.
///
/// Tidak melakukan request otomatis; pemanggil wajib memastikan konsen
/// jaringan sudah diberikan (lihat `REGISTRY.md` §6).
final class RegistryClient {
  RegistryClient({
    required this.trustStore,
    required this.transport,
    required this.cacheStore,
    required this.userAgent,
    Uri? indexUrl,
    DateTime Function()? clock,
  }) : indexUrl = indexUrl ?? registryIndexUrl,
       _clock = clock ?? DateTime.now;

  final RegistryTrustStore trustStore;
  final RegistryTransport transport;
  final RegistryCacheStore cacheStore;
  final String userAgent;
  final Uri indexUrl;
  final DateTime Function() _clock;

  Map<String, String> get _headers => <String, String>{
    'User-Agent': userAgent,
    'Accept': 'application/json',
  };

  /// Memuat cache terverifikasi, atau `null` bila belum ada cache.
  ///
  /// Signature diverifikasi ulang setiap kali cache dimuat.
  Future<RegistrySnapshot?> loadCached() async {
    final cache = await cacheStore.read();
    if (cache == null) {
      return null;
    }
    final index = await _verifyIndex(
      indexBytes: cache.indexBytes,
      signatureBytes: cache.signatureBytes,
      sourceUrl: cache.sourceUrl,
    );
    return RegistrySnapshot(
      index: index,
      sourceUrl: cache.sourceUrl,
      fetchedAt: cache.fetchedAt,
      fromCache: true,
      stale: _isStale(cache.fetchedAt),
    );
  }

  /// Mengunduh, memverifikasi, lalu menyimpan indeks baru.
  Future<RegistrySnapshot> refresh() async {
    final stopwatch = Stopwatch()..start();
    final response = await transport.get(
      indexUrl,
      headers: _headers,
      maxBytes: registryMaxIndexBytes,
      timeout: registryFetchTimeout,
    );
    _checkSize(response.bytes, registryMaxIndexBytes);

    final remaining = registryFetchTimeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw const RegistryClientException(
        'registry.offline',
        'Waktu permintaan registry habis.',
      );
    }

    final signatureUrl = _signatureUrl(response.finalUrl);
    final signatureResponse = await transport.get(
      signatureUrl,
      headers: _headers,
      maxBytes: registryMaxSignatureBytes,
      timeout: remaining,
    );
    _checkSize(signatureResponse.bytes, registryMaxSignatureBytes);

    final index = await _verifyIndex(
      indexBytes: response.bytes,
      signatureBytes: signatureResponse.bytes,
      sourceUrl: response.finalUrl,
    );

    final cachedIndex = await _verifiedCachedIndex();
    if (cachedIndex != null && index.sequence < cachedIndex.sequence) {
      throw RegistryClientException(
        'registry.replay',
        'Indeks registry lebih lama dari cache.',
        <String, Object?>{
          'incoming': index.sequence,
          'cached': cachedIndex.sequence,
        },
      );
    }

    final fetchedAt = _clock().toUtc();
    await cacheStore.write(
      RegistryCache(
        indexBytes: response.bytes,
        signatureBytes: signatureResponse.bytes,
        fetchedAt: fetchedAt,
        sourceUrl: response.finalUrl,
      ),
    );
    return RegistrySnapshot(
      index: index,
      sourceUrl: response.finalUrl,
      fetchedAt: fetchedAt,
      fromCache: false,
      stale: false,
    );
  }

  /// Refresh dengan fallback ke cache saat jaringan/HTTP gagal.
  ///
  /// Error signature atau skema tidak pernah di-fallback agar kegagalan
  /// verifikasi tetap terlihat.
  Future<RegistrySnapshot> loadWithFallback() async {
    try {
      return await refresh();
    } on RegistryClientException catch (error) {
      if (!_isNetworkFailure(error)) {
        rethrow;
      }
      final cached = await loadCached();
      if (cached == null) {
        rethrow;
      }
      return cached.asOffline();
    }
  }

  Future<RegistryIndex?> _verifiedCachedIndex() async {
    try {
      final cache = await cacheStore.read();
      if (cache == null) {
        return null;
      }
      return await _verifyIndex(
        indexBytes: cache.indexBytes,
        signatureBytes: cache.signatureBytes,
        sourceUrl: cache.sourceUrl,
      );
    } on RegistryClientException {
      return null;
    } on RegistryFormatException {
      return null;
    }
  }

  Future<RegistryIndex> _verifyIndex({
    required Uint8List indexBytes,
    required Uint8List signatureBytes,
    required Uri sourceUrl,
  }) async {
    final signature = RegistrySignature.fromBytes(signatureBytes);
    await verifyRegistrySignature(
      signature: signature,
      message: registryIndexMessage(indexBytes),
      trustStore: trustStore,
      usage: 'index',
    );
    final index = RegistryIndex.fromBytes(indexBytes);
    index.validateUrls(sourceUrl);
    return index;
  }

  bool _isStale(DateTime fetchedAt) {
    return _clock().toUtc().difference(fetchedAt.toUtc()) > registryCacheTtl;
  }

  bool _isNetworkFailure(RegistryClientException error) {
    return error.code == 'registry.offline' ||
        error.code == 'registry.http' ||
        error.code == 'registry.too_large';
  }

  Uri _signatureUrl(Uri indexUrl) {
    final path = indexUrl.path.endsWith('/')
        ? '${indexUrl.path}registry.json.sig'
        : '${indexUrl.path}.sig';
    return Uri(
      scheme: indexUrl.scheme,
      host: indexUrl.host,
      port: indexUrl.hasPort ? indexUrl.port : null,
      path: path,
    );
  }

  void _checkSize(Uint8List bytes, int maxBytes) {
    if (bytes.length > maxBytes) {
      throw RegistryClientException(
        'registry.too_large',
        'Respons registry melebihi $maxBytes byte.',
        <String, Object?>{'size': bytes.length, 'maxBytes': maxBytes},
      );
    }
  }
}
