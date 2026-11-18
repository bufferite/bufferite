# Lisensi Pihak Ketiga

Bufferite (MIT) memakai paket Dart/Flutter berikut:

| Paket | Lisensi | Kegunaan |
|---|---|---|
| flutter / flutter_riverpod | BSD-3-Clause / MIT | Framework UI + state management |
| sqflite / sqflite_common_ffi | BSD-2-Clause / MIT | Storage SQLite |
| crypto | BSD-3-Clause | Hash/HMAC |
| archive | MIT | Baca/tulis `.berp` (zip) |
| path_provider | BSD-3-Clause | Direktori aplikasi |
| file_picker | MIT | Pilih file (sideload/impor) |
| wasm_run | MIT | Runtime WASM (belum aktif di MVP) |
| Lua 5.4.6 (`lua_runtime.wasm`) | MIT (Lua.org / PUC-Rio) | Interpreter tier `lua` |
| @antonz/lua-wasi 5.4.6 | MIT (Anton Zhiyanov) | Build WASI Lua 5.4.6; SHA-256 `02754c98…0c84` |

Teks lisensi lengkap dapat ditampilkan di aplikasi lewat `showLicensePage`
(Flutter `LicenseRegistry`). Untuk rilis, jalankan generator lisensi agar daftar
ini tersinkron dengan `pubspec.lock`.