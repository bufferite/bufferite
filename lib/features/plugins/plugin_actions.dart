import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';
import '../operations/operation_providers.dart';
import 'plugin_providers.dart';

/// ID plugin core bawaan; disable/hapus memicu peringatan.
const String corePluginId = 'dev.bufferite.core';

/// Aksi enable/disable/hapus plugin.
class PluginActions {
  PluginActions(this._ref);

  final Ref _ref;

  Future<bool> setEnabled(String pluginId, bool enabled) async {
    final repository = _ref.read(pluginRepositoryProvider);
    final updated = await repository.setEnabled(pluginId, enabled);
    if (updated) {
      _ref
          .read(operationRegistryProvider)
          .setPluginAvailability(pluginId, available: enabled);
      _ref.invalidate(installedPluginsProvider);
    }
    return updated;
  }

  Future<bool> remove(String pluginId) async {
    final repository = _ref.read(pluginRepositoryProvider);
    final removed = await repository.delete(pluginId);
    if (removed) {
      _ref.read(operationRegistryProvider).unregisterByPlugin(pluginId);
      _ref.invalidate(installedPluginsProvider);
    }
    return removed;
  }
}

final pluginActionsProvider = Provider<PluginActions>(
  (ref) => PluginActions(ref),
);
