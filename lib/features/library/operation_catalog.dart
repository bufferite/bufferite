import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plugin/installed_plugin.dart';
import '../../core/plugin/operation_registry.dart';
import '../operations/operation_providers.dart';

/// Metadata plugin terpasang, diisi F11 saat Plugin Manager tersedia.
///
/// Test atau bootstrap dapat meng-override nilai ini.
final pluginMetadataProvider = Provider<Map<String, InstalledPlugin>>(
  (ref) => const <String, InstalledPlugin>{},
);

/// Satu baris katalog operasi: descriptor + metadata plugin pengasuhnya.
final class OperationCatalogEntry {
  const OperationCatalogEntry({
    required this.entry,
    this.plugin,
    required this.enabled,
  });

  final RegisteredOperation entry;
  final InstalledPlugin? plugin;
  final bool enabled;

  String get operationId => entry.descriptor.id;
  String get name => entry.descriptor.name;
  String get pluginId => entry.descriptor.pluginId;
  String? get pluginName => plugin?.manifest.name;
  bool get verified => plugin?.verified ?? true;
  bool get supported => entry.descriptor.isSupported;
}

/// Operasi dari plugin aktif, digabung dengan metadata plugin.
///
/// Plugin tanpa metadata (mis. core saat bootstrap) dianggap aktif.
final operationCatalogProvider = Provider<List<OperationCatalogEntry>>((ref) {
  final registry = ref.watch(operationRegistryProvider);
  final metadata = ref.watch(pluginMetadataProvider);

  final entries = <OperationCatalogEntry>[];
  for (final entry in registry.all(includeUnsupported: true)) {
    final plugin = metadata[entry.descriptor.pluginId];
    final enabled = plugin?.enabled ?? true;
    if (!enabled) {
      continue;
    }
    entries.add(
      OperationCatalogEntry(entry: entry, plugin: plugin, enabled: enabled),
    );
  }
  entries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return List<OperationCatalogEntry>.unmodifiable(entries);
});
