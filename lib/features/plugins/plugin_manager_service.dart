import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/operations/core_operations.dart';
import '../../core/plugin/installed_plugin.dart';
import '../../core/plugin/manifest_registrar.dart';
import '../../core/plugin/operation.dart';
import '../../core/plugin/operation_registry.dart';
import '../../core/plugin/plugin_manifest.dart';
import '../../core/plugin/plugin_package.dart';
import '../../core/plugin/plugin_package_store.dart';
import '../../core/runtime/plugin_runtime.dart';
import '../../core/runtime/sandbox.dart';
import '../../core/storage/storage_providers.dart';
import '../operations/operation_providers.dart';
import '../settings/settings_provider.dart';
import 'plugin_repository.dart';

typedef PluginPackageWriter = Future<String> Function(PluginPackage package);

/// Orkestrasi siklus plugin: instal, verifikasi metadata, aktivasi, hapus, dan
/// registrasi operasi saat bootstrap (F04-T10).
///
/// Service tidak menyentuh file picker maupun UI sehingga dapat diuji dengan
/// storage in-memory; penulisan paket diinjeksi lewat [writePackage].
final class PluginManagerService {
  factory PluginManagerService({
    required PluginRepository repository,
    required OperationRegistry registry,
    required PluginPackageWriter writePackage,
    Operation? Function(String operationId)? executorFor,
    PluginRuntimeLoader? runtimeLoader,
  }) {
    return PluginManagerService._(
      repository,
      registry,
      writePackage,
      executorFor,
      runtimeLoader,
    );
  }

  PluginManagerService._(
    this._repository,
    this._registry,
    this._writePackage,
    this._executorFor,
    this._runtimeLoader,
  );

  final PluginRepository _repository;
  final OperationRegistry _registry;
  final PluginPackageWriter _writePackage;
  final Operation? Function(String operationId)? _executorFor;
  final PluginRuntimeLoader? _runtimeLoader;

  OperationRegistry get registry => _registry;

  /// Plugin terpasang diurutkan waktu instalasi.
  Future<List<InstalledPlugin>> installed() => _repository.list();

  /// Instal paket `.berp` dari byte mentah.
  ///
  /// [verified] hanya `true` untuk paket yang hash-nya sudah dicocokkan dengan
  /// pin tepercaya (mis. core bundel).
  Future<InstalledPlugin> installBytes(
    Uint8List bytes, {
    PluginSource source = PluginSource.sideload,
    bool verified = false,
    PluginProvenance? provenance,
  }) {
    return install(
      PluginPackage.decode(bytes),
      source: source,
      verified: verified,
      provenance: provenance,
    );
  }

  /// Ekstrak paket, simpan metadata, lalu daftarkan operasinya ke registry.
  ///
  /// Instalasi ulang plugin yang sama mengganti descriptor lama agar perubahan
  /// versi/izin tidak menyisakan entri basi.
  Future<InstalledPlugin> install(
    PluginPackage package, {
    required PluginSource source,
    bool verified = false,
    PluginProvenance? provenance,
  }) async {
    final installPath = await _writePackage(package);
    final plugin = InstalledPlugin(
      manifest: package.manifest,
      source: source,
      installedAt: DateTime.now().toUtc(),
      verified: verified,
      installPath: installPath,
      provenance: provenance,
    );
    await _repository.save(plugin);
    await _runtimeLoader?.evictPlugin(plugin.pluginId);
    _registry.unregisterByPlugin(plugin.pluginId);
    register(plugin);
    return plugin;
  }

  /// Daftarkan satu plugin (aktif atau nonaktif) ke registry.
  void register(InstalledPlugin plugin) {
    final operations = <String, ManifestOperation>{
      for (final operation in plugin.manifest.operations)
        operation.id: operation,
    };
    ManifestRegistrar(_registry).register(
      plugin.manifest,
      enabled: plugin.enabled,
      executorFor: (operationId) {
        final core = _executorFor?.call(operationId);
        if (core != null) {
          return core;
        }
        final operation = operations[operationId];
        if (operation == null || _runtimeLoader == null) {
          return null;
        }
        return _runtimeLoader.operationFor(plugin, operation);
      },
    );
  }

  /// Daftarkan ulang semua plugin terpasang; dipakai saat bootstrap aplikasi.
  Future<List<InstalledPlugin>> restore() async {
    final plugins = await _repository.list();
    for (final plugin in plugins) {
      _registry.unregisterByPlugin(plugin.pluginId);
      register(plugin);
    }
    return plugins;
  }

  /// Aktifkan/nonaktifkan plugin. `false` bila plugin tidak ditemukan.
  Future<bool> setEnabled(String pluginId, bool enabled) async {
    final plugin = await _repository.byId(pluginId);
    if (plugin == null) {
      return false;
    }
    final updated = plugin.copyWith(enabled: enabled);
    await _repository.save(updated);
    await _runtimeLoader?.evictPlugin(pluginId);
    _registry.unregisterByPlugin(pluginId);
    register(updated);
    return true;
  }

  /// Hapus metadata plugin dan operasinya dari registry.
  Future<bool> remove(String pluginId) async {
    final removed = await _repository.delete(pluginId);
    if (removed) {
      await _runtimeLoader?.evictPlugin(pluginId);
      _registry.unregisterByPlugin(pluginId);
    }
    return removed;
  }
}

/// Service plugin dengan storage SQLite aplikasi dan direktori paket nyata.
final pluginManagerServiceProvider = Provider<PluginManagerService>((ref) {
  return PluginManagerService(
    repository: ref.watch(pluginRepositoryProvider),
    registry: ref.read(operationRegistryProvider),
    writePackage: (package) async {
      final support = await getApplicationSupportDirectory();
      return PluginPackageStore(
        Directory('${support.path}/plugins'),
      ).install(package);
    },
    executorFor: (operationId) => coreOperationsById[operationId],
    runtimeLoader: PluginRuntimeLoader(
      sandboxConfig: () =>
          ref.read(settingsProvider).value?.sandboxConfig ??
          SandboxConfig.defaults,
    ),
  );
});
