import 'dart:convert';

import '../../core/error/app_error.dart';
import '../../core/plugin/installed_plugin.dart';
import '../../core/storage/app_database.dart';

/// Menyimpan metadata plugin terpasang di SQLite.
///
/// JSON `InstalledPlugin` menjadi sumber kebenaran; kolom terpisah dipakai
/// untuk query dan status. Pembaruan memakai `UPDATE` lalu `INSERT` agar baris
/// izin tidak ikut terhapus oleh `REPLACE`.
final class PluginRepository {
  PluginRepository(this._database);

  final AppDatabase _database;

  Future<void> save(InstalledPlugin plugin) async {
    final db = await _database.open();
    final values = <String, Object?>{
      'plugin_id': plugin.pluginId,
      'version': plugin.version.toString(),
      'source': plugin.source.name,
      'enabled': plugin.enabled ? 1 : 0,
      'verified': plugin.verified ? 1 : 0,
      'installed_at': plugin.installedAt.millisecondsSinceEpoch,
      'data': jsonEncode(plugin.toJson()),
    };

    await db.transaction((transaction) async {
      final updated = await transaction.update(
        'plugin',
        values,
        where: 'plugin_id = ?',
        whereArgs: <Object?>[plugin.pluginId],
      );
      if (updated == 0) {
        await transaction.insert('plugin', values);
      }
    });
  }

  Future<InstalledPlugin?> byId(String pluginId) async {
    final db = await _database.open();
    final rows = await db.query(
      'plugin',
      where: 'plugin_id = ?',
      whereArgs: <Object?>[pluginId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _decode(rows.single);
  }

  /// Semua plugin terpasang, diurutkan berdasarkan waktu instalasi.
  Future<List<InstalledPlugin>> list() async {
    final db = await _database.open();
    final rows = await db.query(
      'plugin',
      orderBy: 'installed_at ASC, plugin_id ASC',
    );
    return List<InstalledPlugin>.unmodifiable(rows.map(_decode));
  }

  /// Mengubah status aktif plugin. Mengembalikan `false` jika tidak ditemukan.
  Future<bool> setEnabled(String pluginId, bool enabled) async {
    final plugin = await byId(pluginId);
    if (plugin == null) {
      return false;
    }
    await save(plugin.copyWith(enabled: enabled));
    return true;
  }

  /// Menghapus plugin beserta izinnya (foreign key cascade).
  Future<bool> delete(String pluginId) async {
    final db = await _database.open();
    final deleted = await db.delete(
      'plugin',
      where: 'plugin_id = ?',
      whereArgs: <Object?>[pluginId],
    );
    return deleted > 0;
  }

  InstalledPlugin _decode(Map<String, Object?> row) {
    try {
      final decoded = jsonDecode(row['data']! as String);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Data plugin bukan objek JSON.');
      }
      return InstalledPlugin.fromJson(decoded);
    } on Object catch (error) {
      throw AppError(
        category: ErrorCategory.storage,
        code: 'storage.corrupt_plugin',
        message: 'Data plugin rusak dan tidak dapat dibaca.',
        details: <String, Object?>{
          'pluginId': row['plugin_id'],
          'error': error.toString(),
        },
      );
    }
  }
}
