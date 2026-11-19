import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/plugins/plugin_manager_service.dart';
import '../../features/plugins/plugin_repository.dart';
import '../storage/storage_providers.dart';
import 'core_bootstrap_service.dart';

/// ID plugin core yang diharapkan terpasang saat bootstrap.
const String bootstrapCorePluginId = 'dev.bufferite.core';

/// Hasil pemeriksaan bootstrap core.berp.
final class CoreBootstrapResult {
  const CoreBootstrapResult.ready() : ready = true, error = null;

  const CoreBootstrapResult.failed(this.error) : ready = false;

  final bool ready;

  /// Error asli agar UI dapat menerjemahkannya sesuai bahasa aktif.
  final Object? error;
}

/// Memeriksa core.berp; bila belum terpasang, memasang versi bundel dari aset.
///
/// Setelah itu semua plugin terpasang didaftarkan ke registry agar operasinya
/// tersedia setiap kali aplikasi dibuka. Tidak melempar error: kegagalan
/// dikembalikan sebagai status agar UI tetap dapat dibuka.
final coreBootstrapProvider = FutureProvider<CoreBootstrapResult>((ref) async {
  try {
    final PluginRepository repository = ref.watch(pluginRepositoryProvider);
    final service = ref.read(coreBootstrapServiceProvider);

    final existing = await repository.byId(bootstrapCorePluginId);
    if (existing == null || !CoreBootstrapService.isUsableCore(existing)) {
      await service.installBundledCore();
    }

    await ref.read(pluginManagerServiceProvider).restore();
    return const CoreBootstrapResult.ready();
  } on Object catch (error) {
    return CoreBootstrapResult.failed(error);
  }
});
