import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../core/runtime/sandbox.dart';
import '../../core/storage/app_database.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode parse(String? value) {
    for (final mode in values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return system;
  }
}

/// Bahasa antarmuka yang didukung.
enum AppLanguage {
  indonesian('id'),
  english('en');

  const AppLanguage(this.code);

  /// Kode locale yang dipakai katalog `assets/i18n/<code>.json`.
  final String code;

  static AppLanguage parse(String? value) {
    for (final language in values) {
      if (language.name == value || language.code == value) {
        return language;
      }
    }
    return indonesian;
  }
}

/// Preferensi aplikasi yang aman secara default.
final class AppSettings {
  AppSettings({
    this.themeMode = AppThemeMode.system,
    this.language = AppLanguage.indonesian,
    this.stepTimeout = const Duration(seconds: 2),
    this.memoryLimitBytes = 64 * 1024 * 1024,
    this.optInLogging = false,
    this.registryConsent = false,
  }) {
    if (stepTimeout <= Duration.zero) {
      throw ArgumentError.value(
        stepTimeout,
        'stepTimeout',
        'Batas waktu harus lebih dari nol.',
      );
    }
    if (memoryLimitBytes <= 0) {
      throw ArgumentError.value(
        memoryLimitBytes,
        'memoryLimitBytes',
        'Batas memori harus lebih dari nol.',
      );
    }
  }

  static final AppSettings defaults = AppSettings();

  final AppThemeMode themeMode;
  final AppLanguage language;
  final Duration stepTimeout;
  final int memoryLimitBytes;

  /// Log diagnostic hanya dikirim bila pengguna memilih ikut serta.
  final bool optInLogging;

  /// Izin mengakses katalog registry resmi lewat jaringan.
  final bool registryConsent;

  SandboxConfig get sandboxConfig => SandboxConfig(
    stepTimeout: stepTimeout,
    memoryLimitBytes: memoryLimitBytes,
  );

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppLanguage? language,
    Duration? stepTimeout,
    int? memoryLimitBytes,
    bool? optInLogging,
    bool? registryConsent,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      stepTimeout: stepTimeout ?? this.stepTimeout,
      memoryLimitBytes: memoryLimitBytes ?? this.memoryLimitBytes,
      optInLogging: optInLogging ?? this.optInLogging,
      registryConsent: registryConsent ?? this.registryConsent,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.language == language &&
        other.stepTimeout == stepTimeout &&
        other.memoryLimitBytes == memoryLimitBytes &&
        other.optInLogging == optInLogging &&
        other.registryConsent == registryConsent;
  }

  @override
  int get hashCode {
    return Object.hash(
      themeMode,
      language,
      stepTimeout,
      memoryLimitBytes,
      optInLogging,
      registryConsent,
    );
  }
}

/// Menyimpan preferensi sebagai key-value di SQLite.
///
/// Nilai yang hilang atau rusak jatuh ke default per-key agar satu baris
/// bermasalah tidak membuat aplikasi gagal start.
final class SettingsRepository {
  SettingsRepository(this._database);

  static const String themeKey = 'theme';
  static const String languageKey = 'language';
  static const String stepTimeoutKey = 'sandbox.step_timeout_ms';
  static const String memoryLimitKey = 'sandbox.memory_limit_bytes';
  static const String optInLoggingKey = 'logging.opt_in';
  static const String registryConsentKey = 'registry.consent';

  static const List<String> _keys = <String>[
    themeKey,
    languageKey,
    stepTimeoutKey,
    memoryLimitKey,
    optInLoggingKey,
    registryConsentKey,
  ];

  final AppDatabase _database;

  Future<AppSettings> load() async {
    final db = await _database.open();
    final placeholders = List<String>.filled(_keys.length, '?').join(', ');
    final rows = await db.query(
      'setting',
      where: 'key IN ($placeholders)',
      whereArgs: _keys,
    );
    final values = <String, String>{
      for (final row in rows)
        if (row['key'] is String && row['value'] is String)
          row['key']! as String: row['value']! as String,
    };

    return AppSettings(
      themeMode: AppThemeMode.parse(values[themeKey]),
      language: AppLanguage.parse(values[languageKey]),
      stepTimeout: Duration(
        milliseconds: _positiveInt(
          values[stepTimeoutKey],
          AppSettings.defaults.stepTimeout.inMilliseconds,
        ),
      ),
      memoryLimitBytes: _positiveInt(
        values[memoryLimitKey],
        AppSettings.defaults.memoryLimitBytes,
      ),
      optInLogging: _bool(values[optInLoggingKey]),
      registryConsent: _bool(values[registryConsentKey]),
    );
  }

  Future<void> save(AppSettings settings) async {
    final db = await _database.open();
    final values = <String, String>{
      themeKey: settings.themeMode.name,
      languageKey: settings.language.name,
      stepTimeoutKey: settings.stepTimeout.inMilliseconds.toString(),
      memoryLimitKey: settings.memoryLimitBytes.toString(),
      optInLoggingKey: settings.optInLogging ? 'true' : 'false',
      registryConsentKey: settings.registryConsent ? 'true' : 'false',
    };

    await db.transaction((transaction) async {
      for (final entry in values.entries) {
        await transaction.insert('setting', <String, Object?>{
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}

int _positiveInt(String? value, int fallback) {
  final parsed = int.tryParse(value ?? '');
  return parsed != null && parsed > 0 ? parsed : fallback;
}

bool _bool(String? value) {
  if (value == 'true' || value == '1') {
    return true;
  }
  return false;
}
