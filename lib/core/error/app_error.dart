/// Kategori error lintas layer aplikasi.
enum ErrorCategory {
  validation,
  plugin,
  runtime,
  permission,
  storage,
  unsupported,
  cancelled,
}

/// Error terstruktur Bufferite.
///
/// Semua error yang menyeberang batas runtime/UI harus memakai tipe ini.
/// `code` stabil untuk test dan telemetri lokal; `message` untuk manusia.
final class AppError implements Exception {
  const AppError({
    required this.category,
    required this.code,
    required this.message,
    this.pluginId,
    this.stepId,
    this.details = const <String, Object?>{},
  });

  final ErrorCategory category;
  final String code;
  final String message;
  final String? pluginId;
  final String? stepId;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'category': category.name,
      'code': code,
      'message': message,
      if (pluginId != null) 'pluginId': pluginId,
      if (stepId != null) 'stepId': stepId,
      if (details.isNotEmpty) 'details': details,
    };
  }

  factory AppError.fromJson(Map<String, Object?> json) {
    final categoryName = json['category'];
    final code = json['code'];
    final message = json['message'];

    if (categoryName is! String || code is! String || message is! String) {
      throw const FormatException(
        'Error JSON harus memuat category, code, dan message bertipe string.',
      );
    }

    final category = ErrorCategory.values
        .where((value) => value.name == categoryName)
        .firstOrNull;
    if (category == null) {
      throw FormatException('Kategori error tidak dikenal: $categoryName');
    }

    final details = json['details'];
    return AppError(
      category: category,
      code: code,
      message: message,
      pluginId: json['pluginId'] as String?,
      stepId: json['stepId'] as String?,
      details: details is Map<String, Object?>
          ? Map<String, Object?>.unmodifiable(details)
          : const <String, Object?>{},
    );
  }

  AppError copyWith({
    ErrorCategory? category,
    String? code,
    String? message,
    String? pluginId,
    String? stepId,
    Map<String, Object?>? details,
  }) {
    return AppError(
      category: category ?? this.category,
      code: code ?? this.code,
      message: message ?? this.message,
      pluginId: pluginId ?? this.pluginId,
      stepId: stepId ?? this.stepId,
      details: details ?? this.details,
    );
  }

  @override
  String toString() => 'AppError($code): $message';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
