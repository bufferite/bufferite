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
    await _update((current) => current.copyWith(stepTimeout: timeout));
  }

  Future<void> setMemoryLimitBytes(int bytes) async {
    await _update((current) => current.copyWith(memoryLimitBytes: bytes));
  }

  Future<void> setOptInLogging(bool enabled) async {
    await _update((current) => current.copyWith(optInLogging: enabled));
  }

  Future<void> setRegistryConsent(bool enabled) async {
    await _update((current) => current.copyWith(registryConsent: enabled));
  }

  /// Memuat ulang dari repository sebelum menyimpan agar perubahan dari
  /// controller lain (tema/bahasa) tidak tertimpa nilai lama.
  Future<void> _update(AppSettings Function(AppSettings) transform) async {
    final repository = ref.read(settingsRepositoryProvider);
    final updated = transform(await repository.load());
    await repository.save(updated);
    state = AsyncData(updated);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
