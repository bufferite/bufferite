import 'package:flutter/widgets.dart';

import '../../../core/error/app_error.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/localized_error.dart';
import '../../../core/registry/registry_error.dart';
import '../../../core/registry/registry_index.dart';

/// Pesan registry sesuai bahasa aktif, dengan fallback pesan asli.
String registryErrorText(BuildContext context, Object error) {
  if (error is AppError) {
    return context.trError(error);
  }

  final (code, details) = switch (error) {
    RegistryClientException() => (error.code, error.details),
    RegistryFormatException() => (error.code, error.details),
    _ => (null, const <String, Object?>{}),
  };
  if (code == null) {
    return '$error';
  }

  final suffix = code.startsWith('registry.')
      ? code.substring('registry.'.length)
      : code;
  final localizations = AppLocalizationsScope.of(context);
  final template = localizations.trOrNull('registry.errors.$suffix');
  if (template == null) {
    return '$error';
  }
  return localizations.format(
    template,
    args: <String, Object?>{...details, 'code': code},
  );
}
