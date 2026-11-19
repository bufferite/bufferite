import 'dart:convert';
import 'dart:typed_data';

import 'registry_error.dart';
import 'registry_index.dart';
import 'registry_signature.dart';

/// Batas file cache registry (indeks + signature + metadata).
const int registryMaxCacheBytes = 8 * 1024 * 1024;

/// Cache indeks registry beserta signature dan waktu pengambilan.
final class RegistryCache {
  const RegistryCache({
    required this.indexBytes,
    required this.signatureBytes,
    required this.fetchedAt,
    required this.sourceUrl,
  });

  final Uint8List indexBytes;
  final Uint8List signatureBytes;
  final DateTime fetchedAt;
  final Uri sourceUrl;

  factory RegistryCache.fromBytes(List<int> bytes) {
    if (bytes.length > registryMaxCacheBytes) {
      throw const RegistryClientException(
        'registry.cache_corrupt',
        'Cache registry melebihi batas ukuran.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (error) {
      throw RegistryClientException(
        'registry.cache_corrupt',
        'Cache registry bukan JSON valid: $error',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const RegistryClientException(
        'registry.cache_corrupt',
        'Cache registry harus berupa objek JSON.',
      );
    }
    if (decoded['version'] != 1) {
      throw const RegistryClientException(
        'registry.cache_corrupt',
        'Versi cache registry tidak didukung.',
      );
    }

    final fetchedAtValue = decoded['fetchedAt'];
    final fetchedAt = fetchedAtValue is String
        ? DateTime.tryParse(fetchedAtValue)
        : null;
    if (fetchedAt == null || !fetchedAt.isUtc) {
      throw const RegistryClientException(
        'registry.cache_corrupt',
        'fetchedAt cache harus ISO-8601 UTC.',
      );
    }

    final sourceValue = decoded['sourceUrl'];
    final sourceUrl = sourceValue is String ? Uri.tryParse(sourceValue) : null;
    if (sourceUrl == null ||
        sourceUrl.scheme != 'https' ||
        sourceUrl.host.isEmpty) {
      throw const RegistryClientException(
        'registry.cache_corrupt',
        'sourceUrl cache harus URL HTTPS.',
      );
    }

    return RegistryCache(
      indexBytes: _decodeBytes(
        decoded['index'],
        registryMaxIndexBytes,
        'indeks',
      ),
      signatureBytes: _decodeBytes(
        decoded['signature'],
        registryMaxSignatureBytes,
        'signature',
      ),
      fetchedAt: fetchedAt,
      sourceUrl: sourceUrl,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': 1,
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      'sourceUrl': sourceUrl.toString(),
      'index': base64Encode(indexBytes),
      'signature': base64Encode(signatureBytes),
    };
  }

  Uint8List encode() {
    return Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
  }
}

Uint8List _decodeBytes(Object? value, int maxBytes, String label) {
  if (value is! String) {
    throw RegistryClientException(
      'registry.cache_corrupt',
      '$label cache wajib berupa base64.',
    );
  }
  final Uint8List decoded;
  try {
    decoded = base64Decode(value);
  } on FormatException {
    throw RegistryClientException(
      'registry.cache_corrupt',
      '$label cache bukan base64 valid.',
    );
  }
  if (decoded.isEmpty || decoded.length > maxBytes) {
    throw RegistryClientException(
      'registry.cache_corrupt',
      '$label cache tidak masuk batas ukuran.',
      <String, Object?>{'size': decoded.length, 'maxBytes': maxBytes},
    );
  }
  return decoded;
}

/// Penyimpanan cache registry yang dapat diganti pada test.
abstract interface class RegistryCacheStore {
  Future<RegistryCache?> read();

  Future<void> write(RegistryCache cache);

  Future<void> clear();
}
