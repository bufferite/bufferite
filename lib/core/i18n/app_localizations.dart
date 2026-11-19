import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

/// Terjemahan aplikasi dari katalog JSON di `assets/i18n/`.
///
/// Katalog dimuat sekali lewat [preload] sebelum `runApp`. Setelah itu
/// pergantian bahasa bersifat sinkron: `BufferiteApp` memilih instance sesuai
/// locale dan menaruhnya di [AppLocalizationsScope].
class AppLocalizations {
  const AppLocalizations._(this.locale, this._strings);

  static const Locale defaultLocale = Locale('id');

  static const List<Locale> supportedLocales = <Locale>[
    Locale('id'),
    Locale('en'),
  ];

  static const String _assetPrefix = 'assets/i18n';

  static final Map<String, Map<String, String>> _catalogs =
      <String, Map<String, String>>{};

  /// Fallback untuk widget yang diuji tanpa [AppLocalizationsScope].
  ///
  /// Di aplikasi, [preload] mengisinya dengan katalog Indonesia.
  static AppLocalizations current = const AppLocalizations._(
    defaultLocale,
    <String, String>{},
  );

  final Locale locale;
  final Map<String, String> _strings;

  /// Memuat seluruh katalog JSON. Aman dipanggil berulang kali.
  static Future<void> preload() async {
    if (_catalogs.isNotEmpty) {
      return;
    }
    for (final locale in supportedLocales) {
      final raw = await rootBundle.loadString(
        '$_assetPrefix/${locale.languageCode}.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          'Katalog ${locale.languageCode} harus berupa objek JSON.',
        );
      }
      _catalogs[locale.languageCode] = Map<String, String>.unmodifiable(
        _flatten(decoded.cast<String, Object?>()),
      );
    }
    current = forLocale(defaultLocale);
  }

  /// Instance untuk [locale], jatuh ke [defaultLocale] bila tidak didukung.
  static AppLocalizations forLocale(Locale locale) {
    final code =
        supportedLocales.any(
          (supported) => supported.languageCode == locale.languageCode,
        )
        ? locale.languageCode
        : defaultLocale.languageCode;
    return AppLocalizations._(
      Locale(code),
      _catalogs[code] ?? const <String, String>{},
    );
  }

  /// Terjemahan untuk [key] dengan interpolasi `{nama}` dari [args].
  ///
  /// Bila key tidak ada di katalog aktif, katalog Indonesia dipakai; bila
  /// tetap tidak ada, key dikembalikan apa adanya.
  String tr(
    String key, {
    Map<String, Object?> args = const <String, Object?>{},
  }) {
    final template =
        _strings[key] ?? _catalogs[defaultLocale.languageCode]?[key] ?? key;
    return _interpolate(template, args);
  }

  /// Terjemahan mentah untuk [key], atau `null` bila tidak tersedia.
  ///
  /// Dipakai saat pemanggil punya fallback sendiri, mis. metadata operasi dari
  /// manifest plugin yang tidak selalu ada di katalog.
  String? trOrNull(String key) {
    return _strings[key] ?? _catalogs[defaultLocale.languageCode]?[key];
  }

  /// Terjemahan untuk [key], atau [fallback] bila tidak tersedia.
  String trOr(String key, String fallback) => trOrNull(key) ?? fallback;

  /// Interpolasi placeholder `{nama}` pada [template].
  ///
  /// Diekspos agar helper lokalisasi lain (mis. pesan error terstruktur) bisa
  /// memakai aturan interpolasi yang sama.
  String format(
    String template, {
    Map<String, Object?> args = const <String, Object?>{},
  }) {
    return _interpolate(template, args);
  }

  /// Seperti [tr], tetapi memilih varian `_one`/`_other` berdasarkan [count].
  String trPlural(
    String key,
    int count, {
    Map<String, Object?> args = const <String, Object?>{},
  }) {
    final suffix = count == 1 ? '_one' : '_other';
    final template =
        _strings['$key$suffix'] ??
        _catalogs[defaultLocale.languageCode]?['$key$suffix'] ??
        _strings[key] ??
        _catalogs[defaultLocale.languageCode]?[key] ??
        key;
    return _interpolate(template, <String, Object?>{...args, 'count': count});
  }

  static String _interpolate(String template, Map<String, Object?> args) {
    var result = template;
    for (final entry in args.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }

  static Map<String, String> _flatten(
    Map<String, Object?> source, [
    String prefix = '',
  ]) {
    final result = <String, String>{};
    for (final entry in source.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;
      if (value is Map) {
        result.addAll(_flatten(value.cast<String, Object?>(), key));
      } else if (value is String) {
        result[key] = value;
      }
    }
    return result;
  }
}

/// Menyediakan [AppLocalizations] ke seluruh pohon widget.
class AppLocalizationsScope extends InheritedWidget {
  const AppLocalizationsScope({
    super.key,
    required this.localizations,
    required super.child,
  });

  final AppLocalizations localizations;

  static AppLocalizations of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLocalizationsScope>();
    return scope?.localizations ?? AppLocalizations.current;
  }

  @override
  bool updateShouldNotify(AppLocalizationsScope oldWidget) {
    return oldWidget.localizations.locale != localizations.locale;
  }
}

extension AppLocalizationsContextX on BuildContext {
  /// Terjemahan untuk [key] sesuai bahasa aktif.
  String tr(
    String key, {
    Map<String, Object?> args = const <String, Object?>{},
  }) {
    return AppLocalizationsScope.of(this).tr(key, args: args);
  }

  /// Terjemahan untuk [key], atau [fallback] bila tidak tersedia.
  String trOr(String key, String fallback) {
    return AppLocalizationsScope.of(this).trOr(key, fallback);
  }

  /// Terjemahan plural untuk [key] sesuai bahasa aktif.
  String trPlural(
    String key,
    int count, {
    Map<String, Object?> args = const <String, Object?>{},
  }) {
    return AppLocalizationsScope.of(this).trPlural(key, count, args: args);
  }
}
