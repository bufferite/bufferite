import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../error/app_error.dart';

/// Path aset runtime Lua (tier `lua`).
const String luaRuntimeAssetPath = 'assets/lua_runtime.wasm';

/// SHA-256 aset `lua_runtime.wasm` yang dipin (D02).
///
/// Sumber: `@antonz/lua-wasi@5.4.6` (build WASI Lua 5.4.6, MIT).
const String luaRuntimeSha256 =
    '02754c9822caf5112e9a2ccaec3dd29076bf37b51d65cb886ae1606389370c84';

/// Ukuran aset yang diharapkan, untuk gagal cepat sebelum hashing.
const int luaRuntimeSizeBytes = 329167;

/// Memverifikasi aset runtime Lua; melempar error terstruktur bila tidak cocok.
Uint8List verifyLuaRuntime(Uint8List bytes) {
  if (bytes.length != luaRuntimeSizeBytes) {
    throw _integrityError(
      'Ukuran runtime Lua tidak sesuai ($luaRuntimeSizeBytes byte).',
      expected: luaRuntimeSha256,
    );
  }
  final digest = sha256.convert(bytes).toString();
  if (digest != luaRuntimeSha256) {
    throw _integrityError(
      'Hash runtime Lua tidak cocok.',
      expected: luaRuntimeSha256,
      actual: digest,
    );
  }
  return bytes;
}

AppError _integrityError(
  String message, {
  required String expected,
  String? actual,
}) {
  return AppError(
    category: ErrorCategory.plugin,
    code: 'runtime.integrity_mismatch',
    message: message,
    details: <String, Object?>{'expected': expected, 'actual': ?actual},
  );
}
