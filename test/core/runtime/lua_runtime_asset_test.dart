import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/runtime/lua_runtime_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aset lua_runtime.wasm cocok dengan hash pin', () {
    final bytes = File(luaRuntimeAssetPath).readAsBytesSync();
    expect(bytes.length, luaRuntimeSizeBytes);
    expect(verifyLuaRuntime(bytes), same(bytes));
  });

  test('byte yang diubah ditolak', () {
    final bytes = Uint8List.fromList(
      File(luaRuntimeAssetPath).readAsBytesSync(),
    );
    bytes[bytes.length - 1] ^= 0xFF;
    expect(
      () => verifyLuaRuntime(bytes),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.integrity_mismatch',
        ),
      ),
    );
  });

  test('ukuran salah ditolak tanpa hashing', () {
    expect(
      () => verifyLuaRuntime(Uint8List(8)),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.integrity_mismatch',
        ),
      ),
    );
  });
}
