import 'package:crypto/crypto.dart';

import '../plugin/plugin_package.dart';
import 'registry_error.dart';
import 'registry_index.dart';
import 'registry_signature.dart';
import 'registry_transport.dart';

/// Batas total unduhan paket + signature sesuai `REGISTRY.md` §6.
const Duration registryPackageTimeout = Duration(minutes: 2);

/// Paket registry yang sudah lolos hash, signature, dan pencocokan manifest.
final class VerifiedRegistryPackage {
  const VerifiedRegistryPackage({
    required this.package,
    required this.downloadUrl,
    required this.signatureUrl,
    required this.keyId,
    required this.sha256,
  });

  final PluginPackage package;
  final Uri downloadUrl;
  final Uri signatureUrl;
  final String keyId;
  final String sha256;
}

/// Mengunduh paket `.berp` registry dan memverifikasinya sesuai §7.
///
/// Signature indeks sudah diverifikasi oleh `RegistryClient`; kelas ini
/// memverifikasi signature paket dengan domain separation dan mencocokkan
/// manifest dengan entri indeks sebelum paket boleh diinstal.
final class RegistryInstaller {
  RegistryInstaller({
    required this.transport,
    required this.trustStore,
    required this.userAgent,
    this.timeout = registryPackageTimeout,
  });

  final RegistryTransport transport;
  final RegistryTrustStore trustStore;
  final String userAgent;
  final Duration timeout;

  Map<String, String> get _headers => <String, String>{
    'User-Agent': userAgent,
    'Accept': 'application/octet-stream',
  };

  Future<VerifiedRegistryPackage> downloadAndVerify({
    required RegistryEntry entry,
    required RegistryIndex index,
    required Uri indexSourceUrl,
  }) async {
    final stopwatch = Stopwatch()..start();
    final downloadUrl = _resolve(entry.downloadUrl, indexSourceUrl);
    _requireAllowedHost(downloadUrl, index.allowedHosts);

    final response = await transport.get(
      downloadUrl,
      headers: _headers,
      maxBytes: entry.sizeBytes,
      timeout: timeout,
    );
    _requireAllowedHost(response.finalUrl, index.allowedHosts);
    _requireRemaining(stopwatch, indexSourceUrl);

    if (response.bytes.length != entry.sizeBytes) {
      throw RegistryFormatException(
        'registry.download_failed',
        'Ukuran paket tidak sesuai indeks.',
        <String, Object?>{
          'expected': entry.sizeBytes,
          'actual': response.bytes.length,
        },
      );
    }

    final digest = sha256.convert(response.bytes).toString();
    if (digest != entry.sha256) {
      throw RegistryFormatException(
        'registry.hash_mismatch',
        'Hash paket tidak sesuai indeks.',
        <String, Object?>{'expected': entry.sha256, 'actual': digest},
      );
    }

    final signatureUrl = _resolve(entry.effectiveSignatureUrl, indexSourceUrl);
    _requireAllowedHost(signatureUrl, index.allowedHosts);
    final remaining = timeout - stopwatch.elapsed;
    final signatureResponse = await transport.get(
      signatureUrl,
      headers: _headers,
      maxBytes: registryMaxSignatureBytes,
      timeout: remaining,
    );
    _requireAllowedHost(signatureResponse.finalUrl, index.allowedHosts);
    _requireRemaining(stopwatch, indexSourceUrl);

    final signature = RegistrySignature.fromBytes(signatureResponse.bytes);
    try {
      await verifyRegistrySignature(
        signature: signature,
        message: registryPackageMessage(
          pluginId: entry.pluginId,
          version: entry.version.toString(),
          bytes: response.bytes,
        ),
        trustStore: trustStore,
        usage: 'package',
      );
    } on RegistryFormatException catch (error) {
      if (error.code == 'registry.signature_invalid') {
        throw RegistryFormatException(
          'registry.package_signature_invalid',
          error.message,
          <String, Object?>{'cause': error.code},
        );
      }
      rethrow;
    }

    final package = PluginPackage.decode(response.bytes);
    _checkManifest(entry, package);

    return VerifiedRegistryPackage(
      package: package,
      downloadUrl: response.finalUrl,
      signatureUrl: signatureResponse.finalUrl,
      keyId: signature.keyId,
      sha256: digest,
    );
  }

  void _checkManifest(RegistryEntry entry, PluginPackage package) {
    final manifest = package.manifest;
    final permissions = manifest.permissions
        .map((item) => item.wireName)
        .toSet();
    final expected = entry.permissions.map((item) => item.wireName).toSet();
    if (manifest.pluginId != entry.pluginId ||
        manifest.version != entry.version ||
        manifest.tier != entry.tier ||
        !_sameSet(permissions, expected)) {
      throw RegistryFormatException(
        'registry.manifest_mismatch',
        'Manifest paket tidak cocok dengan entri indeks.',
        <String, Object?>{
          'pluginId': manifest.pluginId,
          'version': manifest.version.toString(),
          'tier': manifest.tier.name,
        },
      );
    }
  }

  bool _sameSet(Set<String> left, Set<String> right) {
    return left.length == right.length && left.containsAll(right);
  }

  void _requireAllowedHost(Uri url, List<String> allowedHosts) {
    if (url.scheme != 'https' || url.host.isEmpty) {
      throw RegistryClientException(
        'registry.schema',
        'URL paket harus HTTPS: $url',
        <String, Object?>{'url': url.toString()},
      );
    }
    final host = url.host.toLowerCase();
    if (!allowedHosts.contains(host)) {
      throw RegistryFormatException(
        'registry.schema',
        'Host paket $host tidak ada di allowedHosts.',
        <String, Object?>{'host': host},
      );
    }
  }

  void _requireRemaining(Stopwatch stopwatch, Uri indexSourceUrl) {
    if (stopwatch.elapsed >= timeout) {
      throw RegistryClientException(
        'registry.offline',
        'Waktu unduhan paket habis.',
        <String, Object?>{'url': indexSourceUrl.toString()},
      );
    }
  }

  Uri _resolve(String value, Uri base) {
    final uri = Uri.parse(value);
    return uri.hasScheme ? uri : base.resolveUri(uri);
  }
}
