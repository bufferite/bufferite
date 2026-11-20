# Changelog

Semua perubahan penting didokumentasikan di sini.
Format mengikuti Keep a Changelog; versi mengikuti Semantic Versioning.

## [Unreleased]

### Ditambahkan
- Spesifikasi registry plugin v1 (`REGISTRY.md`): skema `registry.json`,
  signature Ed25519, konsen jaringan, cache, update/rollback, revocation,
  dan acceptance criteria F16.
- Lokalisasi antarmuka EN/ID berbasis katalog JSON
  (`assets/i18n/{id,en}.json`) dengan pemilih bahasa di Settings,
  interpolasi/plural, dan persistensi bahasa lewat `SettingsRepository`.
- Opsi Hapus pada menu tile recipe di Home (selain swipe kiri), lengkap
  dengan dialog konfirmasi dan Undo.
- Log eksekusi opt-in untuk diagnostik lokal (JSONL, rotasi 200 entri /
  256 KiB) dan layar Diagnostik di Settings untuk melihat serta menghapus
  riwayat; log tidak memuat input, output, atau args step.
- Tooling registry (F16-T08): CLI `keygen`, `validate`, `sign`,
  `build-index`, dan `verify`; model `registry.json` + parser/validator,
  signature Ed25519 dengan domain separation, trust store, indeks
  deterministik dengan `sequence` monoton, dan penulisan file atomik.
- Registry resmi: katalog read-only dengan konsen jaringan, cache/offline,
  instalasi terverifikasi, update/rollback dua versi, dan badge
  update/deprecated/yanked/revoked.
- Trust anchor produksi (F16-T03/D13): `assets/registry_keys.json` membundel
  kunci indeks dan paket; kunci indeks disimpan offline, kunci paket di secret
  CI; signing indeks manual dengan deploy yang memverifikasi rebuild
  deterministik.

### Diubah
- Distribusi plugin disederhanakan menjadi PR ke repo `bufferite/plugins`
  (D14); marketplace lanjutan, akun, rating, ulasan, dan laporan ditunda.
  Aplikasi
  tetap read-only dan hanya melakukan pencarian lokal pada katalog.
- Seluruh teks UI Home, Library, Recipe Editor, Plugin Manager, Settings,
  dialog, dan toast dipindahkan ke katalog terjemahan; istilah
  "Ingredients" dipertahankan di kedua bahasa.
- Metadata operasi inti (nama, kategori, label/help/opsi parameter) dan pesan
  error umum (validasi recipe, parameter operasi, impor/ekspor, aset core,
  paket plugin) kini mengikuti bahasa aktif; metadata plugin pihak ketiga
  tetap memakai manifest sebagai fallback.
- Sinkronisasi dokumen dengan kondisi 1.0: `lua_dart` default, engine WASM
  opt-in, status implementasi sideload/bootstrap/isolate, dan penghapusan
  referensi `wasm_run`.
- Recipe Editor: output langsung di bawah input; daftar ingredients dipindah
  ke panel samping (end drawer) dengan tombol Ingredients berikon keranjang
  di AppBar; konfigurasi parameter memakai dialog tengah, bukan bottom sheet.
- Input file di Recipe Editor disimpan sebagai referensi `FileBuffer` dan
  dibaca bertahap di isolate kerja. Ukuran mengikuti batas memori di Settings;
  output step yang melebihi batas dilaporkan sebagai error terstruktur.
- `StepCard`: nama operasi ditampilkan (bukan ID), badge tier/status
  memakai wrap agar aman di panel sempit.
- Dependency `cryptography` 2.9.0 (Ed25519 murni Dart) ditambahkan untuk
  tooling/verifikasi registry; alasan dan alternatif dicatat di
  `ARCHITECTURE.md` §12.

### Diperbaiki
- Daftar recipe di Home tidak diperbarui setelah menyimpan dari Recipe
  Editor; provider daftar/pencarian kini di-invalidate saat editor
  mengembalikan recipe tersimpan.
- File input besar tidak lagi dibaca utuh ke memori sebelum eksekusi,
  sehingga preview tidak memicu OOM; file di atas batas memori ditolak
  dengan pesan lokal sebelum alokasi.
- Paket `.berp` dipindai dari central directory sebelum dekompresi: symlink,
  jumlah entri, dan ukuran deklarasi yang melebihi batas ditolak lebih awal,
  sehingga symlink besar dan zip dengan ratusan ribu entri tidak lagi memicu
  alokasi/dekompresi sebelum validasi. Ditambah uji mutasi byte deterministik.
- Runtime WASM membatasi stdout/stderr sebelum disalin ke memori, membebaskan
  `wasi_config` pada jalur error, memakai deadline epoch relatif, dan
  menyerialkan eksekusi paralel pada worker yang sama agar timeout/pembatalan
  satu step tidak mengganggu step lain.
- Step DSL `rename` menolak JSON dengan kedalaman berlebih sebelum decode,
  mencegah `StackOverflowError` dari rekursi rename/encode.

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