import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../operations/operation_providers.dart';
import 'plugin_manager_service.dart';
import 'plugin_providers.dart';

/// ID plugin core bawaan; disable/hapus memicu peringatan.
const String corePluginId = 'dev.bufferite.core';

/// Aksi enable/disable/hapus plugin untuk UI.
///
/// Logika orkestrasi berada di [PluginManagerService]; kelas ini hanya
/// menyegarkan provider setelah aksi berhasil.
class PluginActions {
  PluginActions(this._ref);

  final Ref _ref;

  Future<bool> setEnabled(String pluginId, bool enabled) async {
    final updated = await _ref
        .read(pluginManagerServiceProvider)
        .setEnabled(pluginId, enabled);
    if (updated) {
      _ref.invalidate(installedPluginsProvider);
      _ref.read(operationsRevisionProvider.notifier).bump();
    }
    return updated;
  }

  Future<bool> remove(String pluginId) async {
    final removed = await _ref
        .read(pluginManagerServiceProvider)
        .remove(pluginId);
    if (removed) {
      _ref.invalidate(installedPluginsProvider);
      _ref.read(operationsRevisionProvider.notifier).bump();
    }
    return removed;
  }
}

final pluginActionsProvider = Provider<PluginActions>(
  (ref) => PluginActions(ref),
);
