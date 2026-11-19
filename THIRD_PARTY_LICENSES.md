# Lisensi Pihak Ketiga

Bufferite (MIT) memakai paket Dart/Flutter berikut:

| Paket | Lisensi | Kegunaan |
|---|---|---|
| flutter / flutter_riverpod | BSD-3-Clause / MIT | Framework UI + state management |
| sqflite / sqflite_common_ffi | BSD-2-Clause / MIT | Storage SQLite |
| crypto | BSD-3-Clause | Hash/HMAC |
| pointycastle | MIT | AES-CBC/CTR |
| archive | MIT | Baca/tulis `.berp` (zip) |
| path_provider | BSD-3-Clause | Direktori aplikasi |
| file_picker | MIT | Pilih file (sideload/impor) |
| wasmtime (C API) 48.0.9 | Apache-2.0 WITH LLVM-exception | Engine Lua WASM (tier `lua` via `LuaEngine.wasm`, 1.1) |
| Lua 5.4.8 (wasm32-wasip1) | MIT | `assets/lua_runtime.wasm` (interpreter Lua, hash di-pin) |
| lua_dart / Lua 5.5.1 | MIT | Runtime tier `lua` (FFI, prebuilt via Kiln) |

Teks lisensi lengkap dapat ditampilkan di aplikasi lewat `showLicensePage`
(Flutter `LicenseRegistry`). Untuk rilis, jalankan generator lisensi agar daftar
ini tersinkron dengan `pubspec.lock`.