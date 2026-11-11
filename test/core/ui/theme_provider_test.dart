import 'dart:io';

import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/core/storage/storage_providers.dart';
import 'package:bufferite/core/ui/theme_provider.dart';
import 'package:bufferite/features/settings/settings_repository.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase appDatabase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'bufferite_theme_provider_',
    );
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/bufferite.db',
    );
  });

  tearDown(() async {
    await appDatabase.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ProviderContainer container() {
    final result = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
    );
    addTearDown(result.dispose);
    return result;
  }

  test('default memakai tema system', () async {
    expect(
      await container().read(themeModeProvider.future),
      AppThemeMode.system,
    );
  });

  test('setMode mengubah state dan persist', () async {
    final first = container();
    await first.read(themeModeProvider.future);

    await first.read(themeModeProvider.notifier).setMode(AppThemeMode.dark);
    expect(first.read(themeModeProvider).value, AppThemeMode.dark);

    final second = container();
    expect(await second.read(themeModeProvider.future), AppThemeMode.dark);
  });

  test('persist hanya mengubah tema, setting lain tetap', () async {
    final first = container();
    await first.read(themeModeProvider.future);
    final repository = SettingsRepository(appDatabase);
    await repository.save(
      AppSettings(themeMode: AppThemeMode.system, optInLogging: true),
    );

    await first.read(themeModeProvider.notifier).setMode(AppThemeMode.light);

    final loaded = await repository.load();
    expect(loaded.themeMode, AppThemeMode.light);
    expect(loaded.optInLogging, isTrue);
  });

  test('themeModeFor memetakan tiga mode', () {
    expect(themeModeFor(AppThemeMode.system), ThemeMode.system);
    expect(themeModeFor(AppThemeMode.light), ThemeMode.light);
    expect(themeModeFor(AppThemeMode.dark), ThemeMode.dark);
  });
}
