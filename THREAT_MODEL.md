# Bufferite — Threat Model (F14-T01)

Versi: 1.0 · Fase: MVP

## 1. Aset yang dilindungi

1. Data pengguna (buffer, file yang dipilih, hasil operasi).
2. Recipe tersimpan (`.brecipe`, SQLite).
3. Plugin terpasang + izin yang diberikan.
4. Integritas runtime (`core.berp`, native `lua_dart` dengan hash dari paket).
5. Privasi: tidak ada eksfiltrasi data tanpa aksi pengguna.

## 2. Aktor

- **Pengguna** — pemilik perangkat.
- **Plugin jahat** — paket `.berp` dari sideload/katalog yang mencoba keluar
  sandbox.
- **Penyerang jaringan** — hanya relevan bila fitur katalog Fase 2 aktif.
- **Penyerang lokal / aplikasi lain** — mencoba membaca data aplikasi atau
  menukar paket.

## 3. Jalur serang dan mitigasi

| # | Jalur serang | Mitigasi |
|---|---|---|
| 1 | Zip-slip / path traversal di `.berp` | Validasi path relatif, tolak `..`, absolut, separator Windows |
| 2 | Zip bomb / entri raksasa | Batas 32 MiB paket, 512 entri, 16 MiB/entri, 64 MiB total |
| 3 | Symlink/duplikat entri | Tolak symlink; tolak duplikat case-insensitive |
| 4 | Paket/runner dimodifikasi | SHA-256 dipin; mismatch = tolak eksekusi |
| 5 | Akses net/fs tanpa izin | `PermissionGuard` + dialog izin; runtime tanpa `os`/`io` |
| 6 | ReDoS dari regex | Batas panjang pola + timeout eksekusi |
| 7 | Kehabisan resource | Batas waktu 2 dtk/operasi, memori 64 MiB |
| 8 | Acak tidak aman | CSPRNG (`Random.secure`) untuk operasi acak |
| 9 | Jalur jaringan implisit | Offline-by-default; jaringan hanya untuk katalog (Fase 2) |
| 10 | Data rusak di storage | Error storage terstruktur; fallback default settings |

## 4. Asumsi & batasan MVP

- Pipeline operasi core berjalan di isolate kerja; Lua juga di isolate kerja
  dengan timeout + interrupt (F03-T04, CP-054/CP-057).
- **Isolate Dart bukan batas keamanan.** Lua 1.0 memakai `lua_dart` (native
  FFI, Lua 5.5.1) di proses aplikasi: tidak ada isolasi memori seperti WASM.
- Sandbox Lua bersifat *capability*: `io`, `dofile`, `loadfile`, `package`,
  `require`, `debug`, serta `os.execute/getenv/exit/remove/rename/setlocale/
  tmpname` tidak tersedia; `load` hanya menerima chunk teks (bytecode ditolak);
  tidak ada host function net/fs; memori dibatasi 64 MiB.
- Tier WASM memakai ABI command WASI v1 (`WasmPluginRuntime`): input via stdin,
  args JSON di argv, output stdout; linker WASI tanpa preopen direktori dan
  tanpa socket. Matriks izin lintas runtime ada di
  `test/core/runtime/permission_matrix_test.dart` (F05-T06/T07/T09, F14-T03).
- Perlindungan data mengandalkan sandbox OS (Android/iOS/desktop), izin
  INTERNET tidak diminta, dan storage scoped.

### 4.1 Batas isolasi Lua 1.0

| Aspek | Status |
|---|---|
| Capability (file/net/proses) | Diblokir di level Lua (library dihapus) |
| Batas memori | 64 MiB via allocator Lua (`memoryLimit`) |
| Waktu / DoS | Timeout + interrupt + kill isolate |
| UI responsif | Ya (isolate kerja) |
| Isolasi memori / kontainmen bug native | **Tidak** (native in-process; engine WASM tersedia sebagai opsi, bukan default 1.0) |
| Tier `wasm` | Isolasi memori WASM; tanpa host function net/fs (WASI tanpa preopen/socket) |
| Plugin tepercaya | Hanya hash paket; sideload `unverified` = tidak tepercaya |
| Sandbox OS | Android/iOS/desktop (UID, scoped storage, tanpa INTERNET) |

Konsekuensi: plugin Lua yang jahat tidak bisa memanggil file/net lewat API
Lua, tetapi **bug native** (Lua/binding/libc) berpotensi keluar dari sandbox
Lua dan menyentuh proses aplikasi. Untuk plugin tak tepercaya, isolasi WASM
atau proses terpisah diperlukan (1.1). Engine WASM + `lua_runtime.wasm`
(CP-063) sudah tervalidasi di Windows dan Android; setelah dijadikan default,
jalur Lua tidak lagi berbagi ruang alamat dengan host (selain engine wasmtime
sendiri).

## 5. Status verifikasi

- Suspected: `test/core/plugin_package_test.dart`,
  `test/core/plugin_integrity_test.dart`, `test/core/plugin_permission_test.dart`.
- Matriks bypass izin DSL/Lua native/Lua WASM: `permission_matrix_test.dart`
  (32 test; F05-T07/F14-T03). Tier `wasm`: `wasm_plugin_runtime_test.dart`
  (fs host diblokir, import host ditolak, exit error, timeout pulih) +
  integration emulator Android.
- Lua 1.0: 12 test sandbox/timeout + integration emulator (CP-057); batas
  isolasi didokumentasikan di §4.1.
- Engine Lua WASM: integration emulator Android (eksekusi + timeout epoch) dan
  kontrak 10 kasus vs `lua_dart` + 5 kasus DSL vs Lua vs WASM (CP-063/CP-065).
- Sisa: keamanan regex terukur (F14-T04), CSPRNG operasi acak (F14-T05),
  audit offline (F14-T06).
