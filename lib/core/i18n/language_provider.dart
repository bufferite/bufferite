import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_repository.dart';
import '../storage/storage_providers.dart';

/// Bahasa antarmuka yang persisten via [SettingsRepository].
final languageProvider = AsyncNotifierProvider<LanguageController, AppLanguage>(
  LanguageController.new,
);

class LanguageController extends AsyncNotifier<AppLanguage> {
  @override
  Future<AppLanguage> build() async {
    return (await ref.watch(settingsRepositoryProvider).load()).language;
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = AsyncData(language);
    final repository = ref.read(settingsRepositoryProvider);
    final settings = await repository.load();
    await repository.save(settings.copyWith(language: language));
  }
}
