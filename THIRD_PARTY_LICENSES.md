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
| wasm_run | MIT | Runtime WASM (belum aktif di MVP) |
| lua_dart / Lua 5.5.1 | MIT | Runtime tier `lua` (FFI, prebuilt via Kiln) |

Teks lisensi lengkap dapat ditampilkan di aplikasi lewat `showLicensePage`
(Flutter `LicenseRegistry`). Untuk rilis, jalankan generator lisensi agar daftar
ini tersinkron dengan `pubspec.lock`.