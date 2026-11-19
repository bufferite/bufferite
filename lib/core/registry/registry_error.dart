/// Error klien registry untuk masalah jaringan, cache, dan replay.
///
/// Error skema/signature tetap memakai `RegistryFormatException` dari
/// `registry_index.dart` dan `registry_signature.dart`.
final class RegistryClientException implements Exception {
  const RegistryClientException(
    this.code,
    this.message, [
    this.details = const <String, Object?>{},
  ]);

  final String code;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => '$code: $message';
}
