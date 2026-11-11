import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../core/storage/app_database.dart';

/// Daftar operasi favorit pengguna.
final class FavoriteRepository {
  FavoriteRepository(this._database);

  final AppDatabase _database;

  /// Menambah favorit. Menambahkan ID yang sama tidak menggandakan baris.
  Future<void> add(String operationId, {DateTime? now}) async {
    final id = _validate(operationId);
    final db = await _database.open();
    await db.insert('favorite', <String, Object?>{
      'operation_id': id,
      'created_at': (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Menghapus favorit. Mengembalikan `false` jika tidak ada.
  Future<bool> remove(String operationId) async {
    final db = await _database.open();
    final deleted = await db.delete(
      'favorite',
      where: 'operation_id = ?',
      whereArgs: <Object?>[operationId],
    );
    return deleted > 0;
  }

  Future<bool> contains(String operationId) async {
    final db = await _database.open();
    final rows = await db.query(
      'favorite',
      columns: <String>['operation_id'],
      where: 'operation_id = ?',
      whereArgs: <Object?>[operationId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Favorit terbaru lebih dulu.
  Future<List<String>> list() async {
    final db = await _database.open();
    final rows = await db.query(
      'favorite',
      columns: <String>['operation_id'],
      orderBy: 'created_at DESC, operation_id ASC',
    );
    return List<String>.unmodifiable(
      rows.map((row) => row['operation_id']! as String),
    );
  }

  String _validate(String operationId) {
    final id = operationId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'ID operasi tidak boleh kosong.',
      );
    }
    return id;
  }
}
