import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/error/app_error.dart';
import '../../core/plugin/installed_plugin.dart';
import '../../core/plugin/manifest_registrar.dart';
import '../../core/plugin/plugin_package.dart';
import '../../core/plugin/plugin_package_store.dart';
import '../../core/storage/storage_providers.dart';
import '../operations/operation_providers.dart';
import 'plugin_providers.dart';

/// Alur sideload plugin dari file `.berp`.
class PluginSideloadService {
  PluginSideloadService(this._ref);

  final Ref _ref;

  /// Memilih dan memvalidasi paket `.berp`. `null` bila dibatalkan.
  Future<PluginPackage?> pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Pilih paket plugin',
      type: FileType.custom,
      allowedExtensions: const <String>['berp'],
    );
    if (file == null) {
      return null;
    }
    final path = file.path;
    if (path == null) {
      throw const AppError(
        category: ErrorCategory.storage,
        code: 'plugin.file_unreadable',
        message: 'File paket tidak dapat dibaca.',
      );
    }
    final handle = File(path);
    return PluginPackage.decode(handle.readAsBytesSync());
  }

  /// Menyimpan paket ke filesystem, metadata ke SQLite, dan operasi ke registry.
  Future<InstalledPlugin> install(PluginPackage package) async {
    final support = await getApplicationSupportDirectory();
    final store = PluginPackageStore(Directory('${support.path}/plugins'));
    final installPath = await store.install(package);

    final plugin = InstalledPlugin(
      manifest: package.manifest,
      source: PluginSource.sideload,
      installedAt: DateTime.now().toUtc(),
      verified: false,
      installPath: installPath,
    );
    await _ref.read(pluginRepositoryProvider).save(plugin);
    ManifestRegistrar(
      _ref.read(operationRegistryProvider),
    ).register(package.manifest);
    _ref.invalidate(installedPluginsProvider);
    return plugin;
  }
}

final pluginSideloadProvider = Provider<PluginSideloadService>(
  (ref) => PluginSideloadService(ref),
);
