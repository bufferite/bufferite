import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';
import 'settings_repository.dart';

/// Preferensi aplikasi (tema, batas sandbox, log) yang persisten.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    return ref.watch(settingsRepositoryProvider).load();
  }

  Future<void> setStepTimeout(Duration timeout) async {
    final current = state.value ?? AppSettings.defaults;
    await _save(current.copyWith(stepTimeout: timeout));
  }

  Future<void> setMemoryLimitBytes(int bytes) async {
    final current = state.value ?? AppSettings.defaults;
    await _save(current.copyWith(memoryLimitBytes: bytes));
  }

  Future<void> setOptInLogging(bool enabled) async {
    final current = state.value ?? AppSettings.defaults;
    await _save(current.copyWith(optInLogging: enabled));
  }

  Future<void> _save(AppSettings settings) async {
    final updated = await ref
        .read(settingsRepositoryProvider)
        .save(settings)
        .then((_) => settings);
    state = AsyncData(updated);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
