import 'dart:convert';
import 'dart:typed_data';

import 'package:bufferite/core/registry/registry_index.dart';
import 'package:bufferite/core/registry/registry_signature.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RegistryTrustStore> _trustStoreFor(
  GeneratedRegistryKey generated, {
  String usage = 'both',
  String status = 'active',
}) async {
  return RegistryTrustStore(<RegistryTrustedKey>[
    RegistryTrustedKey(
      keyId: generated.privateKey.keyId,
      usage: usage,
      publicKey: generated.publicKey,
      status: status,
      createdAt: '2026-11-20',
    ),
  ]);
}

void main() {
  test('Ed25519 sesuai test vector RFC 8032 #1', () async {
    final seed = _hex(
      '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
    );
    final key = RegistryPrivateKey(keyId: 'vector', seed: seed);
    final signature = await signRegistryMessage(key: key, message: '');

    expect(
      _hexString(signature.signature),
      'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155'
      '5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
    );
  });

  test('sign dan verify index dengan trust store', () async {
    final generated = await generateRegistryKey(keyId: 'index-2026');
    final bytes = utf8.encode('{"registryVersion":1}');
    final signature = await signRegistryIndex(
      key: generated.privateKey,
      bytes: bytes,
    );
    final store = await _trustStoreFor(generated);

    await verifyRegistrySignature(
      signature: signature,
      message: registryIndexMessage(bytes),
      trustStore: store,
      usage: 'index',
    );
  });

  test('domain separation menolak signature index sebagai paket', () async {
    final generated = await generateRegistryKey(keyId: 'index-2026');
    final bytes = utf8.encode('konten');
    final signature = await signRegistryIndex(
      key: generated.privateKey,
      bytes: bytes,
    );
    final store = await _trustStoreFor(generated);

    await expectLater(
      verifyRegistrySignature(
        signature: signature,
        message: registryPackageMessage(
          pluginId: 'com.test.pack',
          version: '1.0.0',
          bytes: bytes,
        ),
        trustStore: store,
        usage: 'index',
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

  test('kunci unknown, revoked, dan usage salah ditolak', () async {
    final generated = await generateRegistryKey(keyId: 'index-2026');
    final bytes = utf8.encode('konten');
    final signature = await signRegistryIndex(
      key: generated.privateKey,
      bytes: bytes,
    );
    final message = registryIndexMessage(bytes);

    await expectLater(
      verifyRegistrySignature(
        signature: signature,
        message: message,
        trustStore: const RegistryTrustStore(<RegistryTrustedKey>[]),
        usage: 'index',
      ),
      throwsA(
        isA<RegistryFormatException>().having(
          (error) => error.code,
          'code',
          'registry.key_unknown',
        ),
      ),
    );

    await expectLater(
      verifyRegistrySignature(
        signature: signature,
        message: message,
        trustStore: await _trustStoreFor(generated, status: 'revoked'),
        usage: 'index',
      ),
      throwsA(
        isA<RegistryFormatException>().having(
          (error) => error.code,
          'code',
          'registry.key_revoked',
        ),
      ),
    );

    await expectLater(
      verifyRegistrySignature(
        signature: signature,
        message: message,
        trustStore: await _trustStoreFor(generated, usage: 'package'),
        usage: 'index',
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

  test('signature file round-trip dan batas ukuran', () {
    final signature = RegistrySignature(
      keyId: 'k1',
      signature: Uint8List.fromList(List<int>.generate(64, (index) => index)),
    );
    final parsed = RegistrySignature.fromBytes(utf8.encode(signature.encode()));
    expect(parsed.keyId, 'k1');
    expect(parsed.signature, signature.signature);

    expect(
      () =>
          RegistrySignature.fromBytes(Uint8List(registryMaxSignatureBytes + 1)),
      throwsA(isA<RegistryFormatException>()),
    );
  });

  test('private key file round-trip', () {
    final key = RegistryPrivateKey(
      keyId: 'k1',
      seed: Uint8List.fromList(List<int>.generate(32, (index) => index)),
    );
    final parsed = RegistryPrivateKey.fromBytes(utf8.encode(key.encode()));
    expect(parsed.keyId, key.keyId);
    expect(parsed.seed, key.seed);
  });
}

Uint8List _hex(String value) {
  return Uint8List.fromList(<int>[
    for (var index = 0; index < value.length; index += 2)
      int.parse(value.substring(index, index + 2), radix: 16),
  ]);
}

String _hexString(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
