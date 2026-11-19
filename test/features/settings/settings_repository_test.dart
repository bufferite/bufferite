import 'dart:io';

import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/features/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late SettingsRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bufferite_settings_repo_');
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/bufferite.db',
    );
    repository = SettingsRepository(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('database kosong memakai default aman', () async {
    final settings = await repository.load();

    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.language, AppLanguage.indonesian);
    expect(settings.stepTimeout, const Duration(seconds: 2));
    expect(settings.memoryLimitBytes, 64 * 1024 * 1024);
    expect(settings.optInLogging, isFalse);
    expect(settings.registryConsent, isFalse);
  });

  test('konsen registry tersimpan dan dapat dicabut', () async {
    await repository.save(AppSettings(registryConsent: true));
    expect((await repository.load()).registryConsent, isTrue);

    await repository.save(AppSettings(registryConsent: false));
    expect((await repository.load()).registryConsent, isFalse);
  });

  test('save lalu load mengembalikan nilai yang sama', () async {
    final settings = AppSettings(
      themeMode: AppThemeMode.dark,
      language: AppLanguage.english,
      stepTimeout: const Duration(milliseconds: 750),
      memoryLimitBytes: 8 * 1024 * 1024,
      optInLogging: true,
      registryConsent: true,
    );

    await repository.save(settings);

    expect(await repository.load(), settings);
    expect(
      (await repository.load()).sandboxConfig.stepTimeout,
      settings.stepTimeout,
    );
  });

  test('nilai persist setelah database dibuka ulang', () async {
    await repository.save(
      AppSettings(
        themeMode: AppThemeMode.light,
        language: AppLanguage.english,
        optInLogging: true,
      ),
    );
    await appDatabase.close();

    final reopenedDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/bufferite.db',
    );
    final reopened = SettingsRepository(reopenedDatabase);
    final settings = await reopened.load();
    expect(settings.themeMode, AppThemeMode.light);
    expect(settings.language, AppLanguage.english);
    expect(settings.optInLogging, isTrue);
    await reopenedDatabase.close();
  });

  test('nilai rusak jatuh ke default per-key', () async {
    final db = await appDatabase.open();
    await db.insert('setting', <String, Object?>{
      'key': SettingsRepository.themeKey,
      'value': 'neon',
    });
    await db.insert('setting', <String, Object?>{
      'key': SettingsRepository.stepTimeoutKey,
      'value': '-5',
    });
    await db.insert('setting', <String, Object?>{
      'key': SettingsRepository.memoryLimitKey,
      'value': 'bukan-angka',
    });
    await db.insert('setting', <String, Object?>{
      'key': SettingsRepository.optInLoggingKey,
      'value': 'yes',
    });
    await db.insert('setting', <String, Object?>{
      'key': SettingsRepository.languageKey,
      'value': 'klingon',
    });
    await db.insert('setting', <String, Object?>{
      'key': SettingsRepository.registryConsentKey,
      'value': 'yes',
    });

    final settings = await repository.load();
    expect(settings, AppSettings.defaults);
  });

  test('save dua kali tidak menggandakan key', () async {
    await repository.save(AppSettings.defaults);
    await repository.save(AppSettings(themeMode: AppThemeMode.dark));

    final db = await appDatabase.open();
    expect(await db.query('setting'), hasLength(6));
  });

  test('AppSettings menolak batas resource tidak valid', () {
    expect(() => AppSettings(stepTimeout: Duration.zero), throwsArgumentError);
    expect(() => AppSettings(memoryLimitBytes: 0), throwsArgumentError);
  });
}
