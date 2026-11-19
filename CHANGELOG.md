# Changelog

Semua perubahan penting didokumentasikan di sini.
Format mengikuti Keep a Changelog; versi mengikuti Semantic Versioning.

## [Unreleased]

### Ditambahkan
- Spesifikasi registry plugin v1 (`REGISTRY.md`): skema `registry.json`,
  signature Ed25519, konsen jaringan, cache, update/rollback, revocation,
  dan acceptance criteria F16.

### Diubah
- Sinkronisasi dokumen dengan kondisi 1.0: `lua_dart` default, engine WASM
  opt-in, status implementasi sideload/bootstrap/isolate, dan penghapusan
  referensi `wasm_run`.
- Recipe Editor: output langsung di bawah input; daftar step dipindah ke
  panel samping (end drawer) dengan tombol Step di AppBar; konfigurasi
  parameter memakai dialog tengah, bukan bottom sheet.
- `StepCard`: nama operasi ditampilkan (bukan ID), badge tier/status
  memakai wrap agar aman di panel sempit.

## [1.0.0] - 2026-11-19

Rilis MVP Bufferite.

### Ditambahkan
- Domain engine: `Buffer`, `AppError`, `Result`, kontrak operasi + registry.
- Recipe v1: model, validasi, codec `.brecipe` (5 MiB, migrasi schema).
- Pipeline executor sekuensial: skip, error terstruktur, timeout, cancel, stream.
- Sistem plugin: manifest v1, pembaca `.berp` aman, verifikasi SHA-256,
  lifecycle, izin + `PermissionGuard`.
- Storage SQLite v1 + repository (recipe, plugin, settings, favorite) dan
  penyimpanan paket plugin di filesystem (staging + rename atomik).
- UI: design token + tema light/dark, app shell 3 tab, komponen
  (`AppButton`, `AppBadge`, `StepCard`, `BufferPanel`, `EmptyState`,
  dialog izin, toast+undo).
- Home (cari/buat/hapus/duplikat recipe) dan Recipe Editor (picker, konfigurasi
  param, reorder, hapus+undo, preview live debounce, error per step,
  simpan/guard perubahan, impor/ekspor `.brecipe`, input file).
- Library + Operation Picker (search, chip kategori/favorit) dan Plugin Manager
  (daftar, detail, enable/disable/hapus, sideload + dialog izin, tombol katalog).
- Settings: tema, batas sandbox, opt-in log + hapus log, tentang, reinstal
  core.berp, reset data.
- core.berp tooling: authoring spec, build deterministik + hash, operasi
  encode/decode, hash, format, analysis, utility, AES-CBC/CTR, XOR, dan
  HMAC-SHA1/256/512; audit lisensi & ukuran.
- Keamanan: threat model, test adversarial paket, bypass izin, safe regex
  (anti-ReDoS), CSPRNG, audit offline-default, integration test end-to-end,
  review kripto lanjutan (`SECURITY_REVIEW_CRYPTO.md`).
- Pipeline operasi core berjalan di isolate kerja (UI tetap responsif).
- Runtime Lua (Lua 5.5.1) via `lua_dart`: sandbox tanpa `io`/`os.execute`,
  batas memori, entrypoint `transform(input, args)`, prebuilt per ABI.
- Engine Lua WASI (`LuaEngine.wasm`) berbasis wasmtime C API + cache worker
  persisten: engine/modul dikompilasi sekali per plugin, store baru per step,
  timeout lewat epoch; aset `lua_runtime.wasm` dipin SHA-256.
- Tier plugin `wasm` dengan ABI command WASI v1: input via stdin, args JSON di
  argv, output stdout, tanpa host function net/fs.
- Cache runtime per plugin (LRU 4, idle 5 menit) dan disposal saat plugin
  dinonaktifkan/dihapus.
- Penegakan izin di semua runtime (`requirePermission(cpu)`), sandbox Lua WASM
  disamakan dengan `lua_dart` (`os.rename`/`setlocale` dihapus, `load` hanya
  teks), matriks bypass izin 32 test, dan contract test DSL/Lua/WASM.

### Keamanan
- Tanpa izin INTERNET di manifest utama; offline-by-default.
- Batas sandbox default: timeout 2 dtk, memori 64 MiB, izin `cpu`.

### Diketahui belum ada
- Libwasmtime hanya dikemas di varian debug Android; build release 1.0 belum
  memuat engine sehingga tier `wasm`/`LuaEngine.wasm` memerlukan build yang
  menyertakan library.
- Verifikasi perangkat arm64 fisik (emulator x86_64 sudah lulus).
- Katalog plugin daring dan signature registry (Fase 2).
- Streaming file besar dan AI assistant (Fase 2/3).