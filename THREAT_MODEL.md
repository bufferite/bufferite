# Bufferite — Threat Model (F14-T01)

Versi: 1.1 · Fase: MVP selesai + rencana Fase 2 (registry)

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
- **Penyerang jaringan** — relevan saat katalog registry Fase 2 aktif
  (MITM, CDN/registry dimodifikasi, replay indeks).
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
| 9 | Jalur jaringan implisit | Offline-by-default; jaringan hanya untuk katalog (Fase 2) setelah konsen |
| 10 | Data rusak di storage | Error storage terstruktur; fallback default settings |
| 11 | Indeks registry dimodifikasi | Signature Ed25519 indeks + trust store di aplikasi (`REGISTRY.md` §5) |
| 12 | Paket registry ditukar setelah unduh | SHA-256 + signature paket diverifikasi sebelum `.berp` dibuka |
| 13 | Kunci signing dicuri/diganti | Public key di-pin; rotasi 90 hari; pencabutan kunci lewat rilis aplikasi (plugin `revoked` lewat indeks) |
| 14 | Replay indeks lama / downgrade | `sequence` monoton; semver; konfirmasi downgrade; status `revoked` |
| 15 | Registry/CDN jadi pengintai | Hanya `GET` saat pengguna membuka katalog; tanpa cookie/ID/telemetri |
| 16 | Cache registry dirusak | Signature diverifikasi ulang setiap cache dimuat; fail closed |

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
- Perlindungan data mengandalkan sandbox OS (Android/iOS/desktop), storage
  scoped, dan tidak adanya izin INTERNET pada rilis 1.0. Registry Fase 2 akan
  menambahkan INTERNET hanya setelah konsen pengguna.

### 4.1 Batas isolasi Lua 1.0

| Aspek | Status |
|---|---|
| Capability (file/net/proses) | Diblokir di level Lua (library dihapus) |
| Batas memori | 64 MiB via allocator Lua (`memoryLimit`) |
| Waktu / DoS | Timeout + interrupt + kill isolate |
| UI responsif | Ya (isolate kerja) |
| Isolasi memori / kontainmen bug native | **Tidak** (native in-process; engine WASM tersedia sebagai opsi, bukan default 1.0) |
| Tier `wasm` | Isolasi memori WASM; tanpa host function net/fs (WASI tanpa preopen/socket) |
| Plugin tepercaya | Registry resmi: hash + signature Ed25519 (rencana F16); sideload `unverified` = tidak tepercaya |
| Sandbox OS | Android/iOS/desktop (UID, scoped storage); tanpa INTERNET di 1.0 |

Konsekuensi: plugin Lua yang jahat tidak bisa memanggil file/net lewat API
Lua, tetapi **bug native** (Lua/binding/libc) berpotensi keluar dari sandbox
Lua dan menyentuh proses aplikasi. Untuk plugin tak tepercaya, isolasi WASM
atau proses terpisah lebih kuat. Engine WASM + `lua_runtime.wasm` (CP-063)
sudah tervalidasi di Windows dan Android, tetapi default 1.0 tetap
`lua_dart` (D11); jalur Lua WASM tidak berbagi ruang alamat dengan host
selain engine wasmtime sendiri.

### 4.2 Registry (Fase 2, rencana)

- Trust anchor: public key Ed25519 di-pin di aplikasi, bukan diambil dari
  registry. Menambah/mencabut kunci memerlukan rilis aplikasi.
- Indeks `registry.json` dan setiap paket `.berp` memiliki signature
  terpisah dengan domain separation; hash SHA-256 + ukuran ikut diverifikasi.
- Metadata (`pluginId`, versi, izin, URL, hash) diautentikasi oleh signature
  indeks; manifest paket harus cocok dengan entri.
- `sequence` monoton mencegah replay indeks lama; status `yanked`/`revoked`
  disebarkan lewat indeks bertanda tangan.
- Cache diverifikasi ulang saat dimuat. Tanpa jaringan, revocation terbaru
  tidak diketahui — batasan yang ditampilkan di UI.
- Detail lengkap: `REGISTRY.md` §5–§10.

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
- F14 selesai: ReDoS (F14-T04), CSPRNG (F14-T05), dan audit offline
  (F14-T06) sudah diuji.
- Sisa untuk registry publik: F16-T07 (audit/fuzzing parser indeks/paket dan
  runtime WASM) serta test signature/rollback F16-T01..T04. Belum ada kode
  registry.
