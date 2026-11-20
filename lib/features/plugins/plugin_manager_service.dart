import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/error/app_error.dart';
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
typedef PluginManifestReader =
    Future<PluginManifest?> Function(String pluginId, String version);
typedef PluginInstallPathResolver =
    Future<String?> Function(String pluginId, String version);
typedef PluginVersionRemover =
    Future<void> Function(String pluginId, String version);
typedef PluginVersionPruner =
    Future<void> Function(String pluginId, Set<String> keepVersions);

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
    PluginManifestReader? readManifest,
    PluginInstallPathResolver? resolveInstallPath,
    PluginVersionRemover? removeVersion,
    PluginVersionPruner? pruneVersions,
  }) {
    return PluginManagerService._(
      repository,
      registry,
      writePackage,
      executorFor,
      runtimeLoader,
      readManifest,
      resolveInstallPath,
      removeVersion,
      pruneVersions,
    );
  }

  PluginManagerService._(
    this._repository,
    this._registry,
    this._writePackage,
    this._executorFor,
    this._runtimeLoader,
    this._readManifest,
    this._resolveInstallPath,
    this._removeVersion,
    this._pruneVersions,
  );

  final PluginRepository _repository;
  final OperationRegistry _registry;
  final PluginPackageWriter _writePackage;
  final Operation? Function(String operationId)? _executorFor;
  final PluginRuntimeLoader? _runtimeLoader;
  final PluginManifestReader? _readManifest;
  final PluginInstallPathResolver? _resolveInstallPath;
  final PluginVersionRemover? _removeVersion;
  final PluginVersionPruner? _pruneVersions;

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
  /// versi/izin tidak menyisakan entri basi. Status enable/disable lama
  /// dipertahankan saat reinstall/update.
  Future<InstalledPlugin> install(
    PluginPackage package, {
    required PluginSource source,
    bool verified = false,
    PluginProvenance? provenance,
  }) async {
    final existing = await _repository.byId(package.manifest.pluginId);
    final installPath = await _writePackage(package);
    final plugin = InstalledPlugin(
      manifest: package.manifest,
      source: source,
      installedAt: existing?.installedAt ?? DateTime.now().toUtc(),
      enabled: existing?.enabled ?? true,
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

  /// Pasang versi baru dan kembalikan versi lama bila aktivasi gagal.
  ///
  /// Metadata, operasi, dan direktori versi baru dibersihkan sebelum error
  /// dilempar. Versi lama tetap menjadi plugin aktif.
  Future<InstalledPlugin> update(
    PluginPackage package, {
    required PluginSource source,
    bool verified = false,
    PluginProvenance? provenance,
  }) async {
    final existing = await _repository.byId(package.manifest.pluginId);
    if (existing == null) {
      return install(
        package,
        source: source,
        verified: verified,
        provenance: provenance,
      );
    }
    if (existing.version == package.manifest.version) {
      return install(
        package,
        source: source,
        verified: verified,
        provenance: provenance,
      );
    }

    final installPath = await _writePackage(package);
    final next = InstalledPlugin(
      manifest: package.manifest,
      source: source,
      installedAt: existing.installedAt,
      enabled: existing.enabled,
      verified: verified,
      installPath: installPath,
      provenance: provenance,
    );

    try {
      await _repository.save(next);
      await _activate(next);
    } on Object catch (error) {
      var rolledBack = false;
      try {
        await _removeVersion?.call(existing.pluginId, next.version.toString());
        await _repository.save(existing);
        await _activate(existing);
        rolledBack = true;
      } on Object {
        // Kegagalan pemulihan tidak boleh menutupi error update asli.
      }
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.update_failed',
        message:
            'Update ${package.manifest.name} gagal; versi sebelumnya '
            'dipulihkan.',
        details: <String, Object?>{
          'pluginId': existing.pluginId,
          'version': next.version.toString(),
          'previousVersion': existing.version.toString(),
          'rolledBack': rolledBack,
          'cause': error.toString(),
        },
      );
    }

    await _prune(existing.pluginId, <String>{
      next.version.toString(),
      existing.version.toString(),
    });
    return next;
  }

  /// Kembalikan plugin ke versi sebelumnya yang masih disimpan.
  Future<InstalledPlugin> rollback(String pluginId) async {
    final existing = await _repository.byId(pluginId);
    final provenance = existing?.provenance;
    final previousVersion = provenance?.previousVersion;
    if (existing == null || previousVersion == null) {
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.rollback_unavailable',
        message: 'Versi sebelumnya tidak tersedia untuk plugin ini.',
        details: <String, Object?>{'pluginId': pluginId},
      );
    }
    final manifest = await _readManifest?.call(pluginId, previousVersion);
    final installPath = await _resolveInstallPath?.call(
      pluginId,
      previousVersion,
    );
    if (manifest == null || installPath == null) {
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.rollback_unavailable',
        message: 'Versi $previousVersion tidak ditemukan di perangkat.',
        details: <String, Object?>{
          'pluginId': pluginId,
          'version': previousVersion,
        },
      );
    }

    final next = InstalledPlugin(
      manifest: manifest,
      source: provenance?.previousSource ?? existing.source,
      installedAt: existing.installedAt,
      enabled: existing.enabled,
      verified: provenance?.previousVerified ?? existing.verified,
      installPath: installPath,
      provenance: provenance == null
          ? null
          : PluginProvenance(
              registryUrl: provenance.registryUrl,
              keyId: provenance.keyId,
              sha256: provenance.sha256,
              previousVersion: existing.version.toString(),
              previousSource: existing.source,
              previousVerified: existing.verified,
            ),
    );

    try {
      await _repository.save(next);
      await _activate(next);
    } on Object catch (error) {
      try {
        await _repository.save(existing);
        await _activate(existing);
      } on Object {
        // Versi lama adalah fallback terakhir; error asli tetap dilaporkan.
      }
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.rollback_failed',
        message: 'Rollback plugin gagal; versi aktif tidak diubah.',
        details: <String, Object?>{
          'pluginId': pluginId,
          'version': previousVersion,
          'cause': error.toString(),
        },
      );
    }

    await _prune(pluginId, <String>{
      previousVersion,
      existing.version.toString(),
    });
    return next;
  }

  /// Daftarkan satu plugin (aktif atau nonaktif) ke registry.
  List<AppError> register(InstalledPlugin plugin) {
    final operations = <String, ManifestOperation>{
      for (final operation in plugin.manifest.operations)
        operation.id: operation,
    };
    return ManifestRegistrar(_registry).register(
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

  Future<void> _activate(InstalledPlugin plugin) async {
    await _runtimeLoader?.evictPlugin(plugin.pluginId);
    _registry.unregisterByPlugin(plugin.pluginId);
    final errors = register(plugin);
    if (errors.isNotEmpty) {
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.activation_failed',
        message: errors.first.message,
        details: <String, Object?>{
          'pluginId': plugin.pluginId,
          'cause': errors.first.code,
        },
      );
    }
    await _runtimeLoader?.validate(plugin);
  }

  Future<void> _prune(String pluginId, Set<String> keep) async {
    try {
      await _pruneVersions?.call(pluginId, keep);
    } on Object {
      // Retensi bersifat best-effort; update/rollback sudah sukses.
    }
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
  PluginPackageStore? packageStore;
  Future<PluginPackageStore> resolveStore() async {
    if (packageStore != null) {
      return packageStore!;
    }
    final support = await getApplicationSupportDirectory();
    return packageStore = PluginPackageStore(
      Directory('${support.path}/plugins'),
    );
  }

  return PluginManagerService(
    repository: ref.watch(pluginRepositoryProvider),
    registry: ref.read(operationRegistryProvider),
    writePackage: (package) async => (await resolveStore()).install(package),
    executorFor: (operationId) => coreOperationsById[operationId],
    runtimeLoader: PluginRuntimeLoader(
      sandboxConfig: () =>
          ref.read(settingsProvider).value?.sandboxConfig ??
          SandboxConfig.defaults,
    ),
    readManifest: (pluginId, version) async =>
        (await resolveStore()).readManifest(pluginId, version),
    resolveInstallPath: (pluginId, version) async =>
        (await resolveStore()).installPath(pluginId, version),
    removeVersion: (pluginId, version) async =>
        (await resolveStore()).removeVersion(pluginId, version),
    pruneVersions: (pluginId, keep) async =>
        (await resolveStore()).retainVersions(pluginId, keep),
  );
});
