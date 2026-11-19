import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import 'registry_index.dart';

/// Batas file signature sesuai `REGISTRY.md` §4.2.
const int registryMaxSignatureBytes = 4 * 1024;

const String _indexDomain = 'bufferite-registry-v1:index';
const String _packageDomain = 'bufferite-registry-v1:package';

/// Pesan yang ditandatangani untuk indeks (§5.2).
String registryIndexMessage(List<int> bytes) {
  return '$_indexDomain\n${sha256.convert(bytes)}\n${bytes.length}';
}

/// Pesan yang ditandatangani untuk paket (§5.2).
String registryPackageMessage({
  required String pluginId,
  required String version,
  required List<int> bytes,
}) {
  return '$_packageDomain\n$pluginId\n$version\n'
      '${sha256.convert(bytes)}\n${bytes.length}';
}

/// Isi file `<objek>.sig`.
final class RegistrySignature {
  const RegistrySignature({required this.keyId, required this.signature});

  final String keyId;
  final Uint8List signature;

  factory RegistrySignature.fromBytes(List<int> bytes) {
    if (bytes.length > registryMaxSignatureBytes) {
      throw const RegistryFormatException(
        'registry.signature_invalid',
        'File signature melebihi 4 KiB.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (error) {
      throw RegistryFormatException(
        'registry.signature_invalid',
        'Signature bukan JSON valid: $error',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const RegistryFormatException(
        'registry.signature_invalid',
        'Signature harus berupa objek JSON.',
      );
    }
    return RegistrySignature.fromJson(decoded);
  }

  factory RegistrySignature.fromJson(Map<String, Object?> json) {
    if (json['algorithm'] != 'ed25519') {
      throw const RegistryFormatException(
        'registry.signature_invalid',
        'algorithm signature harus ed25519.',
      );
    }
    final keyId = json['keyId'];
    if (keyId is! String || keyId.isEmpty || keyId.length > 80) {
      throw const RegistryFormatException(
        'registry.signature_invalid',
        'keyId signature tidak valid.',
      );
    }
    final encoded = json['signature'];
    if (encoded is! String) {
      throw const RegistryFormatException(
        'registry.signature_invalid',
        'signature wajib berupa base64.',
      );
    }
    final Uint8List signature;
    try {
      signature = base64Decode(encoded);
    } on FormatException {
      throw const RegistryFormatException(
        'registry.signature_invalid',
        'signature bukan base64 valid.',
      );
    }
    if (signature.length != 64) {
      throw const RegistryFormatException(
        'registry.signature_invalid',
        'Signature Ed25519 harus 64 byte.',
      );
    }
    return RegistrySignature(keyId: keyId, signature: signature);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'algorithm': 'ed25519',
      'keyId': keyId,
      'signature': base64Encode(signature),
    };
  }

  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';
}

/// Private key lokal untuk CLI. Custody produksi mengikuti D13.
final class RegistryPrivateKey {
  const RegistryPrivateKey({required this.keyId, required this.seed});

  final String keyId;
  final Uint8List seed;

  factory RegistryPrivateKey.fromBytes(List<int> bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (error) {
      throw RegistryFormatException(
        'registry.key_invalid',
        'File kunci bukan JSON valid: $error',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const RegistryFormatException(
        'registry.key_invalid',
        'File kunci harus berupa objek JSON.',
      );
    }
    return RegistryPrivateKey.fromJson(decoded);
  }

  factory RegistryPrivateKey.fromJson(Map<String, Object?> json) {
    if (json['algorithm'] != 'ed25519') {
      throw const RegistryFormatException(
        'registry.key_invalid',
        'algorithm kunci harus ed25519.',
      );
    }
    final keyId = json['keyId'];
    if (keyId is! String || keyId.isEmpty || keyId.length > 80) {
      throw const RegistryFormatException(
        'registry.key_invalid',
        'keyId kunci tidak valid.',
      );
    }
    final encoded = json['privateKey'];
    if (encoded is! String) {
      throw const RegistryFormatException(
        'registry.key_invalid',
        'privateKey wajib berupa base64.',
      );
    }
    final Uint8List seed;
    try {
      seed = base64Decode(encoded);
    } on FormatException {
      throw const RegistryFormatException(
        'registry.key_invalid',
        'privateKey bukan base64 valid.',
      );
    }
    if (seed.length != 32) {
      throw const RegistryFormatException(
        'registry.key_invalid',
        'Seed Ed25519 harus 32 byte.',
      );
    }
    return RegistryPrivateKey(keyId: keyId, seed: seed);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'algorithm': 'ed25519',
      'keyId': keyId,
      'privateKey': base64Encode(seed),
    };
  }

  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';
}

final class GeneratedRegistryKey {
  const GeneratedRegistryKey({
    required this.privateKey,
    required this.publicKey,
  });

  final RegistryPrivateKey privateKey;
  final Uint8List publicKey;
}

/// Buat pasangan kunci Ed25519 baru.
Future<GeneratedRegistryKey> generateRegistryKey({
  required String keyId,
}) async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final data = await keyPair.extract();
  final publicKey = await keyPair.extractPublicKey();
  return GeneratedRegistryKey(
    privateKey: RegistryPrivateKey(
      keyId: keyId,
      seed: Uint8List.fromList(data.bytes),
    ),
    publicKey: Uint8List.fromList(publicKey.bytes),
  );
}

/// Public key yang di-pin di trust store.
final class RegistryTrustedKey {
  const RegistryTrustedKey({
    required this.keyId,
    required this.usage,
    required this.publicKey,
    required this.status,
    required this.createdAt,
  });

  final String keyId;
  final String usage;
  final Uint8List publicKey;
  final String status;
  final String createdAt;

  bool get isActive => status == 'active';
  bool allows(String requested) => usage == 'both' || usage == requested;

  factory RegistryTrustedKey.fromJson(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw RegistryFormatException(
        'registry.key_invalid',
        'keys[$index] harus berupa objek.',
      );
    }
    if (raw['algorithm'] != 'ed25519') {
      throw RegistryFormatException(
        'registry.key_invalid',
        'keys[$index].algorithm harus ed25519.',
      );
    }
    final keyId = raw['keyId'];
    if (keyId is! String || keyId.isEmpty || keyId.length > 80) {
      throw RegistryFormatException(
        'registry.key_invalid',
        'keys[$index].keyId tidak valid.',
      );
    }
    final usage = raw['usage'];
    if (usage != 'index' && usage != 'package' && usage != 'both') {
      throw RegistryFormatException(
        'registry.key_invalid',
        'keys[$index].usage tidak valid.',
      );
    }
    final status = raw['status'];
    if (status != 'active' && status != 'revoked') {
      throw RegistryFormatException(
        'registry.key_invalid',
        'keys[$index].status tidak valid.',
      );
    }
    final createdAt = raw['createdAt'];
    if (createdAt is! String || createdAt.isEmpty) {
      throw RegistryFormatException(
        'registry.key_invalid',
        'keys[$index].createdAt tidak valid.',
      );
    }
    final encoded = raw['publicKey'];
    if (encoded is! String) {
      throw RegistryFormatException(
        'registry.key_invalid',
        'keys[$index].publicKey wajib base64.',
      );
    }
    final Uint8List publicKey;
    try {
      publicKey = base64Decode(encoded);
    } on FormatException {
      throw RegistryFormatException(
        'registry.key_invalid',
        'keys[$index].publicKey bukan base64 valid.',
      );
    }
    if (publicKey.length != 32) {
      throw RegistryFormatException(
        'registry.key_invalid',
        'keys[$index].publicKey harus 32 byte.',
      );
    }
    return RegistryTrustedKey(
      keyId: keyId,
      usage: usage as String,
      publicKey: publicKey,
      status: status as String,
      createdAt: createdAt,
    );
  }
}

/// Trust store `assets/registry_keys.json` (§5.3).
final class RegistryTrustStore {
  const RegistryTrustStore(this.keys);

  final List<RegistryTrustedKey> keys;

  factory RegistryTrustStore.fromBytes(List<int> bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (error) {
      throw RegistryFormatException(
        'registry.key_invalid',
        'Trust store bukan JSON valid: $error',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const RegistryFormatException(
        'registry.key_invalid',
        'Trust store harus berupa objek JSON.',
      );
    }
    final rawKeys = decoded['keys'];
    if (rawKeys is! List<Object?> || rawKeys.isEmpty) {
      throw const RegistryFormatException(
        'registry.key_invalid',
        'Trust store wajib memiliki minimal satu kunci.',
      );
    }
    final keys = <RegistryTrustedKey>[];
    final ids = <String>{};
    for (var index = 0; index < rawKeys.length; index++) {
      final key = RegistryTrustedKey.fromJson(rawKeys[index], index);
      if (!ids.add(key.keyId)) {
        throw RegistryFormatException(
          'registry.key_invalid',
          'keyId duplikat: ${key.keyId}',
        );
      }
      keys.add(key);
    }
    return RegistryTrustStore(List<RegistryTrustedKey>.unmodifiable(keys));
  }

  /// Cari kunci aktif yang cocok. Kunci unknown/revoked ditolak.
  RegistryTrustedKey require(String keyId, {required String usage}) {
    RegistryTrustedKey? found;
    for (final key in keys) {
      if (key.keyId == keyId) {
        found = key;
        break;
      }
    }
    if (found == null) {
      throw RegistryFormatException(
        'registry.key_unknown',
        'keyId tidak dikenal: $keyId',
      );
    }
    if (!found.isActive) {
      throw RegistryFormatException(
        'registry.key_revoked',
        'Kunci $keyId sudah dicabut.',
      );
    }
    if (!found.allows(usage)) {
      throw RegistryFormatException(
        'registry.signature_invalid',
        'Kunci $keyId tidak dipakai untuk $usage.',
      );
    }
    return found;
  }
}

Future<RegistrySignature> signRegistryMessage({
  required RegistryPrivateKey key,
  required String message,
}) async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(key.seed);
  final signature = await algorithm.sign(
    utf8.encode(message),
    keyPair: keyPair,
  );
  return RegistrySignature(
    keyId: key.keyId,
    signature: Uint8List.fromList(signature.bytes),
  );
}

Future<RegistrySignature> signRegistryIndex({
  required RegistryPrivateKey key,
  required List<int> bytes,
}) {
  return signRegistryMessage(key: key, message: registryIndexMessage(bytes));
}

Future<RegistrySignature> signRegistryPackage({
  required RegistryPrivateKey key,
  required String pluginId,
  required String version,
  required List<int> bytes,
}) {
  return signRegistryMessage(
    key: key,
    message: registryPackageMessage(
      pluginId: pluginId,
      version: version,
      bytes: bytes,
    ),
  );
}

/// Verifikasi signature terhadap trust store.
Future<void> verifyRegistrySignature({
  required RegistrySignature signature,
  required String message,
  required RegistryTrustStore trustStore,
  required String usage,
}) async {
  final key = trustStore.require(signature.keyId, usage: usage);
  final algorithm = Ed25519();
  final publicKey = SimplePublicKey(key.publicKey, type: KeyPairType.ed25519);
  final valid = await algorithm.verify(
    utf8.encode(message),
    signature: Signature(signature.signature, publicKey: publicKey),
  );
  if (!valid) {
    throw const RegistryFormatException(
      'registry.signature_invalid',
      'Signature tidak cocok dengan isi file.',
    );
  }
}
