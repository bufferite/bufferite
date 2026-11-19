import 'package:flutter/services.dart';

import '../error/app_error.dart';
import '../plugin/plugin_integrity.dart';
import 'plugin_runtime.dart';

/// Lokasi modul Lua WASI yang dibundel aplikasi.
const String luaRuntimeAssetPath = 'assets/lua_runtime.wasm';

/// SHA-256 `lua_runtime.wasm` (Lua 5.4.8, `wasm32-wasip1`, exception handling).
const String luaRuntimeSha256 =
    'f7ad57f97fd93b79d3c6a0076bd03023dc7fc13546f2ca3525537c3beb3e5dea';

/// Memuat modul Lua WASM dari asset dan memeriksa hash sebelum dipakai.
Future<WasmLuaModule> loadLuaWasmModule({
  AssetBundle? bundle,
  String? libraryPath,
}) async {
  final data = await (bundle ?? rootBundle).load(luaRuntimeAssetPath);
  final bytes = Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );

  final actual = PluginIntegrity.sha256Hex(bytes);
  if (actual != luaRuntimeSha256) {
    throw AppError(
      category: ErrorCategory.runtime,
      code: 'runtime.wasm_hash_mismatch',
      message: 'Hash $luaRuntimeAssetPath tidak cocok.',
      details: <String, Object?>{
        'expected': luaRuntimeSha256,
        'actual': actual,
      },
    );
  }

  return WasmLuaModule(bytes: bytes, libraryPath: libraryPath);
}
