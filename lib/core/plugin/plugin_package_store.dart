import 'dart:io';

import '../error/app_error.dart';
import 'plugin_package.dart';
import 'plugin_path.dart';

/// Menyimpan isi paket plugin ke filesystem.
///
/// Layout: `<root>/<pluginId>/<version>/...`. Instalasi diekstrak ke direktori
/// staging lalu di-rename ke path final agar plugin tidak pernah terlihat
/// setengah tersalin. Staging dibersihkan saat instalasi gagal.
final class PluginPackageStore {
  PluginPackageStore(this.root);

  final Directory root;

  /// Mengekstrak paket dan mengembalikan path instalasi.
  ///
  /// Versi lama pada path yang sama dihapus sebelum rename. Ada jeda kecil
  /// ketika path final tidak ada; pemakaian aman adalah baca hanya setelah
  /// metadata plugin ditandai terpasang.
  Future<String> install(PluginPackage package) async {
    final pluginId = _validateSegment(
      package.manifest.pluginId,
      field: 'pluginId',
    );
    final version = _validateSegment(
      package.manifest.version.toString(),
      field: 'version',
    );
    final targetPath = '${root.path}/$pluginId/$version';
    final stagingPath = '${root.path}/.staging/${_uniqueName()}';

    try {
      await Directory(stagingPath).create(recursive: true);
      for (final entry in package.filesSnapshot().entries) {
        // ponytail: path sudah tervalidasi PluginPackage.decode; cek ulang
        // karena ini trust boundary filesystem.
        final relative = validateRelativePackagePath(
          entry.key,
          code: 'plugin.package_path_invalid',
          field: 'path',
          category: ErrorCategory.plugin,
        );
        final file = File('$stagingPath/$relative');
        await file.create(recursive: true);
        await file.writeAsBytes(entry.value, flush: true);
      }

      final target = Directory(targetPath);
      if (target.existsSync()) {
        await target.delete(recursive: true);
      }
      await Directory(targetPath).parent.create(recursive: true);
      await Directory(stagingPath).rename(targetPath);
      // ponytail: hapus folder staging induk bila kosong; abaikan bila dipakai
      // instalasi lain yang berjalan bersamaan.
      try {
        await Directory('${root.path}/.staging').delete();
      } on FileSystemException {
        // Diabaikan.
      }
      return targetPath;
    } on AppError {
      await _cleanup(stagingPath);
      rethrow;
    } on Object catch (error) {
      await _cleanup(stagingPath);
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.install_failed',
        message: 'Gagal menyimpan paket plugin ke filesystem.',
        details: <String, Object?>{
          'pluginId': package.manifest.pluginId,
          'version': package.manifest.version.toString(),
          'error': error.toString(),
        },
      );
    }
  }

  /// Menghapus seluruh direktori plugin. Mengembalikan `false` jika plugin
  /// tidak pernah terpasang.
  Future<bool> remove(String pluginId) async {
    final id = _validateSegment(pluginId, field: 'pluginId');
    final pluginDir = Directory('${root.path}/$id');
    if (!pluginDir.existsSync()) {
      return false;
    }
    await pluginDir.delete(recursive: true);
    return true;
  }

  /// Path instalasi bila versi tersebut ada, selain itu `null`.
  String? installPath(String pluginId, String version) {
    final id = _validateSegment(pluginId, field: 'pluginId');
    final ver = _validateSegment(version, field: 'version');
    final target = Directory('${root.path}/$id/$ver');
    return target.existsSync() ? target.path : null;
  }

  /// pluginId reverse-DNS dan versi semver sudah tervalidasi parser; cek ini
  /// menjaga store tetap aman jika dipakai langsung dengan string lain.
  String _validateSegment(String value, {required String field}) {
    final segment = value.trim();
    if (segment.isEmpty ||
        segment == '.' ||
        segment == '..' ||
        segment.contains('/') ||
        segment.contains('\\') ||
        segment.contains('\u0000')) {
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.install_path_invalid',
        message: 'Segmen path instalasi plugin tidak valid.',
        details: <String, Object?>{field: value},
      );
    }
    return segment;
  }

  Future<void> _cleanup(String stagingPath) async {
    final staging = Directory(stagingPath);
    if (staging.existsSync()) {
      try {
        await staging.delete(recursive: true);
      } on FileSystemException {
        // Gagal cleanup tidak mengubah error utama; staging dibiarkan untuk
        // dibersihkan saat root dihapus.
      }
    }
  }

  String _uniqueName() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  }
}

int _counter = 0;
