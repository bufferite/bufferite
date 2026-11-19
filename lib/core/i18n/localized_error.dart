import 'package:flutter/widgets.dart';

import '../error/app_error.dart';
import 'app_localizations.dart';

/// Menerjemahkan [error] berdasarkan `code` dan `details`.
///
/// Katalog memakai namespace `errors.<code>`. Untuk error validasi recipe,
/// subkey mengikuti `details.field` (mis. `errors.recipe.invalid.name`).
/// Bila [operationId] diberikan, label parameter yang tampil di pesan ikut
/// diterjemahkan dari metadata operasi.
/// Bila tidak ada entri yang cocok, pesan asli dipakai sebagai fallback agar
/// error plugin/runtime tetap informatif.
String localizedErrorFor(
  AppLocalizations localizations,
  AppError error, {
  String? operationId,
}) {
  final base = 'errors.${error.code}';
  String? template;

  final variant = error.details['variant'];
  if (variant is String) {
    template = localizations.trOrNull('$base.$variant');
  }

  final field = error.details['field'];
  if (template == null && field is String) {
    if (error.details['duplicate'] == true) {
      template = localizations.trOrNull('$base.$field.duplicate');
    }
    template ??= localizations.trOrNull('$base.$field');
  }

  if (template == null && error.code == 'operation.param_out_of_range') {
    if (error.details.containsKey('min')) {
      template = localizations.trOrNull('$base.min');
    } else if (error.details.containsKey('max')) {
      template = localizations.trOrNull('$base.max');
    } else if (error.details.containsKey('value')) {
      template = localizations.trOrNull('$base.select');
    }
  }

  template ??= localizations.trOrNull(base);
  if (template == null) {
    return error.message;
  }

  final args = <String, Object?>{
    ...error.details,
    'code': error.code,
    'message': error.message,
  };
  final param = error.details['param'];
  if (operationId != null && param is String) {
    final label = localizations.trOrNull(
      'operations.$operationId.params.$param.label',
    );
    if (label != null) {
      args['label'] = label;
    }
  }
  return localizations.format(template, args: args);
}

/// Versi [localizedErrorFor] yang membaca locale dari [context].
String localizedError(
  BuildContext context,
  AppError error, {
  String? operationId,
}) {
  return localizedErrorFor(
    AppLocalizationsScope.of(context),
    error,
    operationId: operationId,
  );
}

extension LocalizedErrorContextX on BuildContext {
  /// Pesan [error] sesuai bahasa aktif, dengan fallback ke pesan asli.
  String trError(AppError error, {String? operationId}) {
    return localizedError(this, error, operationId: operationId);
  }

  /// Pesan error apa pun: [AppError] diterjemahkan, objek lain memakai
  /// `toString` agar error tak terduga tetap terlihat.
  String trErrorObject(Object error) {
    return error is AppError ? trError(error) : '$error';
  }
}
