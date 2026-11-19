import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/plugins/plugin_manager_service.dart';
import '../error/app_error.dart';
import '../plugin/installed_plugin.dart';
import '../plugin/plugin_package.dart';

/// Memasang `core.berp` yang dibundel di dalam aplikasi (F04-T08).
///
/// Aplikasi tidak mengunduh apa pun; paket dibaca dari aset lokal. Update core
/// di masa depan tetap bisa lewat sideload (di luar MVP). Penulisan paket dan
/// registrasi operasi didelegasikan ke [PluginManagerService].
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
        details: <String, Object?>{
          'assetPath': assetPath,
          'error': error.toString(),
        },
      );
    }
    if (data.lengthInBytes == 0) {
      throw const AppError(
        category: ErrorCategory.plugin,
        code: 'core.asset_missing',
        message: 'Aset core.berp kosong.',
        details: <String, Object?>{
          'assetPath': assetPath,
          'variant': 'empty',
        },
      );
    }

    final package = PluginPackage.decode(data.buffer.asUint8List());
    return _ref
        .read(pluginManagerServiceProvider)
        .install(package, source: PluginSource.core, verified: true);
  }

  /// Apakah manifest core yang terpasang sudah memuat operasi.
  static bool isUsableCore(InstalledPlugin plugin) =>
      plugin.manifest.operations.isNotEmpty;
}

final coreBootstrapServiceProvider = Provider<CoreBootstrapService>(
  (ref) => CoreBootstrapService(ref),
);
