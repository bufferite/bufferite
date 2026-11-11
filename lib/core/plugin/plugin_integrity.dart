import 'package:crypto/crypto.dart';

import '../error/app_error.dart';

/// Utilitas SHA-256 untuk paket dan entrypoint plugin.
final class PluginIntegrity {
  const PluginIntegrity._();

  static final RegExp _hexPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  static String sha256Hex(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  static bool isValidHash(String value) => _hexPattern.hasMatch(value.trim());

  /// Melempar `plugin.verify_failed` bila hash tidak cocok.
  static void verifyOrThrow({
    required List<int> bytes,
    required String expected,
    String? subject,
  }) {
    final normalized = expected.trim().toLowerCase();
    if (!_hexPattern.hasMatch(normalized)) {
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.hash_invalid',
        message: 'Hash SHA-256 harus berupa hex 64 karakter.',
        details: <String, Object?>{'hash': expected, 'subject': subject},
      );
    }

    final actual = sha256Hex(bytes);
    if (actual != normalized) {
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.verify_failed',
        message: 'Hash paket plugin tidak cocok.',
        details: <String, Object?>{
          'expected': normalized,
          'actual': actual,
          'subject': ?subject,
        },
      );
    }
  }
}
