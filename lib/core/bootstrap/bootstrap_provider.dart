import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';
import 'core_bootstrap_service.dart';

/// ID plugin core yang diharapkan terpasang saat bootstrap.
const String bootstrapCorePluginId = 'dev.bufferite.core';

/// Hasil pemeriksaan bootstrap core.berp.
final class CoreBootstrapResult {
  const CoreBootstrapResult.ready() : ready = true, message = null;

  const CoreBootstrapResult.failed(this.message) : ready = false;

  final bool ready;
  final String? message;
}

/// Memeriksa core.berp; bila belum terpasang, memasang versi bundel dari aset.
///
/// Tidak melempar error: kegagalan dikembalikan sebagai status agar UI tetap
/// dapat dibuka.
final coreBootstrapProvider = FutureProvider<CoreBootstrapResult>((ref) async {
  try {
    final repository = ref.watch(pluginRepositoryProvider);
    final existing = await repository.byId(bootstrapCorePluginId);
    if (existing != null && existing.enabled) {
      return const CoreBootstrapResult.ready();
    }

    await ref.read(coreBootstrapServiceProvider).installBundledCore();
    return const CoreBootstrapResult.ready();
  } on Object catch (error) {
    return CoreBootstrapResult.failed('Bootstrap gagal: $error');
  }
});
