import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_repository.dart';
import '../storage/storage_providers.dart';

/// Controller tema yang persisten via [SettingsRepository].
final themeModeProvider =
    AsyncNotifierProvider<ThemeModeController, AppThemeMode>(
      ThemeModeController.new,
    );

/// Map [AppThemeMode] ke [ThemeMode] Flutter.
ThemeMode themeModeFor(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

final class ThemeModeController extends AsyncNotifier<AppThemeMode> {
  @override
  Future<AppThemeMode> build() async {
    return (await ref.watch(settingsRepositoryProvider).load()).themeMode;
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = AsyncData(mode);
    final repository = ref.read(settingsRepositoryProvider);
    final settings = await repository.load();
    await repository.save(settings.copyWith(themeMode: mode));
  }
}
