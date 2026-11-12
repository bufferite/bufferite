import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';

/// ID plugin core yang diharapkan terpasang saat bootstrap.
const String bootstrapCorePluginId = 'dev.bufferite.core';

/// Hasil pemeriksaan bootstrap core.berp.
final class CoreBootstrapResult {
  const CoreBootstrapResult.ready() : ready = true, message = null;

  const CoreBootstrapResult.failed(this.message) : ready = false;

  final bool ready;
  final String? message;
}

/// Memeriksa apakah `core.berp` sudah terpasang dan aktif.
///
/// Tidak melempar error: kegagalan dikembalikan sebagai status agar UI tetap
/// dapat dibuka.
final coreBootstrapProvider = FutureProvider<CoreBootstrapResult>((ref) async {
  try {
    final plugin = await ref
        .watch(pluginRepositoryProvider)
        .byId(bootstrapCorePluginId);
    if (plugin != null && plugin.enabled) {
      return const CoreBootstrapResult.ready();
    }
    return const CoreBootstrapResult.failed(
      'Operasi inti (core.berp) belum terpasang.',
    );
  } on Object catch (error) {
    return CoreBootstrapResult.failed('Bootstrap gagal: $error');
  }
});
