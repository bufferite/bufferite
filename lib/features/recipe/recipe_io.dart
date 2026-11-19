import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../core/error/app_error.dart';
import 'recipe.dart';
import 'recipe_codec.dart';

/// Impor/ekspor recipe `.brecipe` lewat file picker.
final class RecipeIo {
  RecipeIo([RecipeCodec? codec]) : _codec = codec ?? RecipeCodec();

  static const String extension = 'brecipe';

  final RecipeCodec _codec;

  /// Menyimpan recipe ke file. Mengembalikan URI, atau `null` bila dibatalkan.
  Future<String?> export(Recipe recipe, {String? dialogTitle}) async {
    final encoded = _codec.encode(recipe);
    if (!encoded.isSuccess) {
      throw encoded.errorOrNull!;
    }
    final uri = await FilePicker.saveFile(
      dialogTitle: dialogTitle ?? 'Simpan recipe',
      fileName: '${_safeName(recipe.name)}.$extension',
      mimeType: 'application/json',
      bytes: Uint8List.fromList(utf8.encode(encoded.valueOrNull!)),
    );
    return uri?.toString();
  }

  /// Membaca recipe dari file terpilih.
  ///
  /// Melempar `AppError` kategori `cancelled` bila pengguna membatalkan.
  Future<Recipe> import({String? dialogTitle}) async {
    final file = await FilePicker.pickFile(
      dialogTitle: dialogTitle ?? 'Impor recipe',
      type: FileType.custom,
      allowedExtensions: <String>[extension],
    );
    if (file == null) {
      throw const AppError(
        category: ErrorCategory.cancelled,
        code: 'recipe.import_cancelled',
        message: 'Impor dibatalkan.',
      );
    }

    final bytes = _bytesOf(file);
    if (bytes == null) {
      throw const AppError(
        category: ErrorCategory.storage,
        code: 'recipe.import_failed',
        message: 'Gagal membaca file recipe.',
      );
    }
    final decoded = _codec.decode(utf8.decode(bytes));
    if (!decoded.isSuccess) {
      throw decoded.errorOrNull!;
    }
    return decoded.valueOrNull!;
  }

  Uint8List? _bytesOf(PlatformFile file) {
    final path = file.path;
    if (path == null) {
      return null;
    }
    final handle = File(path);
    return handle.existsSync() ? handle.readAsBytesSync() : null;
  }

  String _safeName(String name) {
    final cleaned = name.trim().isEmpty ? 'recipe' : name.trim();
    return cleaned.replaceAll(RegExp(r'[^\w\-. ]'), '_');
  }
}
