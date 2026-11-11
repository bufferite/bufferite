import 'dart:convert';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../core/error/app_error.dart';
import '../../core/storage/app_database.dart';
import 'recipe.dart';

/// CRUD recipe di SQLite.
///
/// Kolom `name`, `created_at`, dan `updated_at` diduplikasi dari JSON recipe
/// agar daftar dan pencarian tidak perlu mendekode seluruh isi. JSON tetap
/// menjadi sumber kebenaran untuk field lain.
final class RecipeRepository {
  RecipeRepository(this._database);

  final AppDatabase _database;

  /// Menyimpan recipe baru atau memperbarui recipe dengan ID yang sama.
  ///
  /// `created_at` dipertahankan dari baris lama; `updated_at` selalu diisi
  /// waktu sekarang (atau [now] untuk test). Mengembalikan recipe dengan meta
  /// yang sudah diselaraskan.
  Future<Recipe> save(Recipe recipe, {DateTime? now}) async {
    final errors = recipe.validate();
    if (errors.isNotEmpty) {
      throw errors.first;
    }

    final db = await _database.open();
    final timestamp = (now ?? DateTime.now()).toUtc();
    final existing = await db.query(
      'recipe',
      columns: <String>['created_at'],
      where: 'id = ?',
      whereArgs: <Object?>[recipe.id],
      limit: 1,
    );
    final createdAt = existing.isEmpty
        ? recipe.meta?.createdAt?.toUtc() ?? timestamp
        : DateTime.fromMillisecondsSinceEpoch(
            existing.single['created_at']! as int,
            isUtc: true,
          );
    final stored = recipe.copyWith(
      meta: (recipe.meta ?? const RecipeMeta()).copyWith(
        createdAt: createdAt,
        updatedAt: timestamp,
      ),
    );

    await db.insert('recipe', <String, Object?>{
      'id': stored.id,
      'name': stored.name,
      'data': jsonEncode(stored.toJson()),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': timestamp.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return stored;
  }

  /// Mengambil recipe berdasarkan ID, atau `null` jika tidak ada.
  Future<Recipe?> byId(String id) async {
    final db = await _database.open();
    final rows = await db.query(
      'recipe',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _decode(rows.single);
  }

  /// Daftar recipe, terbaru diperbarui lebih dulu.
  ///
  /// [query] mencocokkan nama secara case-insensitive dan literal (bukan pola
  /// SQL), sehingga `%` dan `_` tidak diperlakukan sebagai wildcard.
  Future<List<Recipe>> list({String query = ''}) async {
    final db = await _database.open();
    final trimmed = query.trim();
    final rows = await db.query(
      'recipe',
      where: trimmed.isEmpty ? null : 'instr(lower(name), lower(?)) > 0',
      whereArgs: trimmed.isEmpty ? null : <Object?>[trimmed],
      orderBy: 'updated_at DESC, id ASC',
    );
    return List<Recipe>.unmodifiable(rows.map(_decode));
  }

  /// Menghapus recipe. Mengembalikan `false` jika ID tidak ditemukan.
  Future<bool> delete(String id) async {
    final db = await _database.open();
    final deleted = await db.delete(
      'recipe',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return deleted > 0;
  }

  Recipe _decode(Map<String, Object?> row) {
    try {
      final decoded = jsonDecode(row['data']! as String);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Data recipe bukan objek JSON.');
      }
      return Recipe.fromJson(decoded);
    } on Object catch (error) {
      throw AppError(
        category: ErrorCategory.storage,
        code: 'storage.corrupt_recipe',
        message: 'Data recipe rusak dan tidak dapat dibaca.',
        details: <String, Object?>{'id': row['id'], 'error': error.toString()},
      );
    }
  }
}
