import '../error/app_error.dart';

/// Pembungkus regex yang membatasi risiko ReDoS (F14-T04).
///
/// Dart `RegExp` tidak punya timeout, jadi mitigasi dilakukan dengan:
/// - batas panjang pola,
/// - batas panjang input,
/// - penolakan pola bersarang berkuantitas ganda (heuristik umum ReDoS).
final class SafeRegex {
  const SafeRegex._();

  static const int maxPatternLength = 512;
  static const int maxInputLength = 1 << 20; // 1 MiB karakter.

  /// Pola seperti `(a+)+`, `(.*)*`, `(\d+){2,}` dicurigai katastrofik.
  static final RegExp _nestedQuantifier = RegExp(
    r'\((?:[^()\\]|\\.)*[+*](?:[^()\\]|\\.)*\)\s*[+*{]',
  );

  static AppError _invalid(String message) {
    return AppError(
      category: ErrorCategory.validation,
      code: 'operation.invalid_input',
      message: message,
    );
  }

  /// Mengganti semua kecocokan dengan aman.
  static String replaceAll(
    String input, {
    required String pattern,
    required String replacement,
    bool ignoreCase = false,
  }) {
    if (pattern.isEmpty) {
      throw _invalid('Parameter "pattern" wajib diisi.');
    }
    if (pattern.length > maxPatternLength) {
      throw _invalid('Pola melebihi batas $maxPatternLength karakter.');
    }
    if (input.length > maxInputLength) {
      throw _invalid('Input melebihi batas $maxInputLength karakter.');
    }
    if (_nestedQuantifier.hasMatch(pattern)) {
      throw _invalid('Pola berisi kuantifier bersarang yang berisiko ReDoS.');
    }

    final RegExp regex;
    try {
      regex = RegExp(pattern, caseSensitive: !ignoreCase);
    } on FormatException {
      throw _invalid('Pola regex tidak valid.');
    }
    return input.replaceAll(regex, replacement);
  }
}
