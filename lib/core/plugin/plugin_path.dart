import '../error/app_error.dart';

/// Memvalidasi path relatif di dalam paket plugin.
///
/// Path harus memakai separator `/`, tidak absolut, dan tidak memuat segmen
/// `.` atau `..`. Path traversal dan separator Windows ditolak.
String validateRelativePackagePath(
  String value, {
  String code = 'plugin.entrypoint_invalid',
  String field = 'entrypoint',
  ErrorCategory category = ErrorCategory.validation,
}) {
  if (value.length > 255 ||
      value.startsWith('/') ||
      value.startsWith('\\') ||
      RegExp(r'^[A-Za-z]:').hasMatch(value) ||
      value.contains('\\') ||
      value.contains('\u0000')) {
    throw AppError(
      category: category,
      code: code,
      message: 'Path paket harus path relatif di dalam paket.',
      details: <String, Object?>{field: value},
    );
  }
  for (final segment in value.split('/')) {
    if (segment.isEmpty || segment == '.' || segment == '..') {
      throw AppError(
        category: category,
        code: code,
        message: 'Path paket tidak boleh memuat segmen kosong, ".", atau "..".',
        details: <String, Object?>{field: value},
      );
    }
  }
  return value;
}
