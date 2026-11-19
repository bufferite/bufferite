import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'registry_error.dart';

/// Respons HTTP mentah dari transport registry.
final class RegistryResponse {
  const RegistryResponse({required this.bytes, required this.finalUrl});

  final Uint8List bytes;
  final Uri finalUrl;
}

/// Transport HTTP yang dapat diganti pada test.
abstract interface class RegistryTransport {
  Future<RegistryResponse> get(
    Uri url, {
    required Map<String, String> headers,
    required int maxBytes,
    required Duration timeout,
  });
}

/// Transport HTTPS memakai `dart:io`.
///
/// Redirect diikuti manual agar setiap hop tetap HTTPS dan jumlahnya dibatasi.
final class IoRegistryTransport implements RegistryTransport {
  IoRegistryTransport({
    HttpClient? client,
    this.connectionTimeout = const Duration(seconds: 10),
    this.maxRedirects = 3,
  }) : _client = client ?? HttpClient() {
    _client.connectionTimeout = connectionTimeout;
  }

  final HttpClient _client;
  final Duration connectionTimeout;
  final int maxRedirects;

  @override
  Future<RegistryResponse> get(
    Uri url, {
    required Map<String, String> headers,
    required int maxBytes,
    required Duration timeout,
  }) {
    HttpClientRequest? active;
    return _get(
      url,
      headers: headers,
      maxBytes: maxBytes,
      onRequest: (request) => active = request,
    ).timeout(
      timeout,
      onTimeout: () {
        active?.abort();
        throw const RegistryClientException(
          'registry.offline',
          'Waktu permintaan registry habis.',
        );
      },
    );
  }

  Future<RegistryResponse> _get(
    Uri url, {
    required Map<String, String> headers,
    required int maxBytes,
    required void Function(HttpClientRequest) onRequest,
  }) async {
    var current = url;
    for (var redirect = 0; redirect <= maxRedirects; redirect++) {
      _requireHttps(current);

      final HttpClientRequest request;
      try {
        request = await _client.openUrl('GET', current);
      } on HttpException catch (error) {
        throw RegistryClientException(
          'registry.http',
          'Permintaan registry tidak valid: ${error.message}',
        );
      } on IOException catch (error) {
        throw RegistryClientException(
          'registry.offline',
          'Tidak dapat terhubung ke registry.',
          <String, Object?>{'error': error.toString()},
        );
      }

      onRequest(request);
      request.followRedirects = false;
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }

      final HttpClientResponse response;
      try {
        response = await request.close();
      } on HttpException catch (error) {
        throw RegistryClientException(
          'registry.http',
          'Respons registry tidak valid: ${error.message}',
        );
      } on IOException catch (error) {
        throw RegistryClientException(
          'registry.offline',
          'Koneksi registry terputus.',
          <String, Object?>{'error': error.toString()},
        );
      }

      if (_isRedirect(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null) {
          throw RegistryClientException(
            'registry.http',
            'Redirect registry tanpa header Location.',
            <String, Object?>{'status': response.statusCode},
          );
        }
        if (redirect == maxRedirects) {
          throw RegistryClientException(
            'registry.http',
            'Redirect registry melebihi $maxRedirects hop.',
            <String, Object?>{'url': current.toString()},
          );
        }
        current = current.resolve(location);
        _requireHttps(current);
        continue;
      }

      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw RegistryClientException(
          'registry.http',
          'Registry mengembalikan HTTP ${response.statusCode}.',
          <String, Object?>{
            'status': response.statusCode,
            'url': current.toString(),
          },
        );
      }

      final Uint8List bytes;
      try {
        bytes = await _readBounded(response, maxBytes);
      } on HttpException catch (error) {
        throw RegistryClientException(
          'registry.http',
          'Respons registry tidak valid: ${error.message}',
        );
      } on IOException catch (error) {
        throw RegistryClientException(
          'registry.offline',
          'Koneksi registry terputus saat membaca respons.',
          <String, Object?>{'error': error.toString()},
        );
      }
      return RegistryResponse(bytes: bytes, finalUrl: current);
    }

    throw const RegistryClientException(
      'registry.http',
      'Redirect registry tidak valid.',
    );
  }

  Future<Uint8List> _readBounded(
    HttpClientResponse response,
    int maxBytes,
  ) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (builder.length + chunk.length > maxBytes) {
        throw RegistryClientException(
          'registry.too_large',
          'Respons registry melebihi $maxBytes byte.',
          <String, Object?>{'maxBytes': maxBytes},
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  void close() => _client.close(force: true);
}

void _requireHttps(Uri url) {
  if (url.scheme != 'https' || url.host.isEmpty) {
    throw RegistryClientException(
      'registry.http',
      'URL registry harus HTTPS: $url',
      <String, Object?>{'url': url.toString()},
    );
  }
}

bool _isRedirect(int status) {
  return status == HttpStatus.movedPermanently ||
      status == HttpStatus.found ||
      status == HttpStatus.seeOther ||
      status == HttpStatus.temporaryRedirect ||
      status == HttpStatus.permanentRedirect;
}
