import 'dart:io';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/operations/operation_providers.dart';
import '../error/app_error.dart';
import '../operations/core_operations.dart';
import '../plugin/installed_plugin.dart';
import '../plugin/manifest_registrar.dart';
import '../plugin/operation.dart';
import '../plugin/operation_registry.dart';
import '../plugin/plugin_package.dart';
import '../plugin/plugin_package_store.dart';
import '../storage/storage_providers.dart';

/// Memasang `core.berp` yang dibundel di dalam aplikasi (F04-T08).
///
/// Aplikasi tidak mengunduh apa pun; paket dibaca dari aset lokal. Update core
/// di masa depan tetap bisa lewat sideload (di luar MVP).
final class CoreBootstrapService {
  CoreBootstrapService(this._ref);

  static const String assetPath = 'assets/core.berp';
  static const String corePluginId = 'dev.bufferite.core';

  final Ref _ref;

  /// Memasang core dari aset dan mengembalikan metadata terpasang.
  Future<InstalledPlugin> installBundledCore() async {
    final ByteData data;
    try {
      data = await rootBundle.load(assetPath);
    } on Object catch (error) {
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'core.asset_missing',
        message: 'Aset $assetPath tidak ditemukan di aplikasi.',
        details: <String, Object?>{'error': error.toString()},
      );
    }
    if (data.lengthInBytes == 0) {
      throw const AppError(
        category: ErrorCategory.plugin,
        code: 'core.asset_missing',
        message: 'Aset core.berp kosong.',
      );
    }

    final package = PluginPackage.decode(data.buffer.asUint8List());
    final support = await getApplicationSupportDirectory();
    final store = PluginPackageStore(Directory('${support.path}/plugins'));
    final installPath = await store.install(package);

    final plugin = InstalledPlugin(
      manifest: package.manifest,
      source: PluginSource.core,
      installedAt: DateTime.now().toUtc(),
      enabled: true,
      verified: true,
      installPath: installPath,
    );
    await _ref.read(pluginRepositoryProvider).save(plugin);
    return plugin;
  }

  /// Mendaftarkan operasi core (dan plugin lain) ke registry runtime.
  ///
  /// Executor hanya tersedia untuk operasi core karena tier lain belum punya
  /// runtime (D02). Operasi plugin lain tetap didaftarkan sebagai unsupported.
  void registerOperations(List<InstalledPlugin> plugins) {
    final registrar = ManifestRegistrar(_ref.read(operationRegistryProvider));
    for (final plugin in plugins) {
      registrar.register(
        plugin.manifest,
        enabled: plugin.enabled,
        executorFor: plugin.pluginId == corePluginId ? _coreExecutorFor : null,
      );
    }
  }

  /// Mendaftarkan satu manifest plugin yang baru dipasang/diaktifkan.
  void registerPlugin(InstalledPlugin plugin) {
    ManifestRegistrar(_ref.read(operationRegistryProvider)).register(
      plugin.manifest,
      enabled: plugin.enabled,
      executorFor: plugin.pluginId == corePluginId ? _coreExecutorFor : null,
    );
  }

  OperationRegistry get registry => _ref.read(operationRegistryProvider);

  static Operation? _coreExecutorFor(String operationId) =>
      coreOperationsById[operationId];

  /// Apakah manifest core yang terpasang sudah memuat operasi.
  static bool isUsableCore(InstalledPlugin plugin) =>
      plugin.manifest.operations.isNotEmpty;
}

final coreBootstrapServiceProvider = Provider<CoreBootstrapService>(
  (ref) => CoreBootstrapService(ref),
);
