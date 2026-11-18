# Changelog

Semua perubahan penting didokumentasikan di sini.
Format mengikuti Keep a Changelog; versi mengikuti Semantic Versioning.

## [1.0.0] - 2026-11-14

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

### Keamanan
- Tanpa izin INTERNET di manifest utama; offline-by-default.
- Batas sandbox default: timeout 2 dtk, memori 64 MiB, izin `cpu`.

### Diketahui belum ada
- Aset `lua_runtime.wasm` (Lua 5.4.6 WASI) sudah dibundel & dipin;
  instansiasi runtime menunggu F05-T04.
- Runtime DSL sudah ada (`DSL.md`); integrasi ke loader plugin menunggu
  F05-T07.
- Host isolate pekerja (F03-T04) dan enforcement memori belum aktif.
- Katalog plugin daring (Fase 2).