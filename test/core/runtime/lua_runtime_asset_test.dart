import 'dart:io';

import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/runtime/lua_runtime_asset.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asset bundle palsu untuk menguji isi tanpa rootBundle.
final class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.bytes);

  final Uint8List bytes;

  @override
  Future<ByteData> load(String key) async {
    if (key != luaRuntimeAssetPath) {
      throw ArgumentError.value(key, 'key', 'Asset tidak ada.');
    }
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('aset Lua WASM cocok dengan pin SHA-256', () async {
    final bytes = await File(luaRuntimeAssetPath).readAsBytes();

    final module = await loadLuaWasmModule(
      bundle: _FakeBundle(bytes),
      libraryPath: 'libwasmtime.so',
    );

    expect(module.bytes, bytes);
    expect(module.libraryPath, 'libwasmtime.so');
  });

  test('aset yang diubah ditolak sebelum engine dibuat', () async {
    final bytes = Uint8List.fromList(
      await File(luaRuntimeAssetPath).readAsBytes(),
    );
    bytes[0] ^= 0xff;

    await expectLater(
      loadLuaWasmModule(bundle: _FakeBundle(bytes)),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.wasm_hash_mismatch',
        ),
      ),
    );
  });
}
