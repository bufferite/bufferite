import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_error.dart';
import '../../core/plugin/installed_plugin.dart';
import '../../core/plugin/plugin_package.dart';
import '../operations/operation_providers.dart';
import 'plugin_manager_service.dart';
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

  /// Menyimpan paket, metadata, dan mendaftarkan operasinya.
  Future<InstalledPlugin> install(PluginPackage package) async {
    final plugin = await _ref
        .read(pluginManagerServiceProvider)
        .install(package, source: PluginSource.sideload);
    _ref.invalidate(installedPluginsProvider);
    _ref.read(operationsRevisionProvider.notifier).bump();
    return plugin;
  }
}

final pluginSideloadProvider = Provider<PluginSideloadService>(
  (ref) => PluginSideloadService(ref),
);
