# TODO.md — Bufferite Feature Backlog

Versi: 1.0
Diperbarui: 2026-11-11
Status: Perencanaan MVP
Sumber kebenaran daftar pekerjaan: dokumen ini.
Catatan progres: lihat [progress.md](progress.md).

---

## 0. Konvensi

- Format ID: `F<nn>-T<nn>` (contoh: `F01-T03`), dikelompokkan per fitur.
- Checkbox `[ ]` = belum selesai, `[x]` = selesai. Status detail (berjalan,
  blocked, dibatalkan) dicatat di `progress.md`, bukan di sini.
- Prioritas:
  - `P0` wajib untuk MVP (Fase 0–1).
  - `P1` sebaiknya ada di MVP bila waktu memungkinkan.
  - `P2` pasca-MVP (Fase 2–3).
- Setiap task selesai wajib memenuhi Definisi Done di `AGENT.md` §9:
  kode berjalan, test lulus, dokumen terkait diperbarui, dan checkpoint
  dicatat di `progress.md`.
- Urutan kerja yang disarankan mengikuti dependency:
  `F00 → F01 → F02 → F06 (minimal) → F03 → F04 → F05 → F07 → F08 → F09
  → F10 → F11 → F12 → F13 → F14 → F15`.
- Jangan mengerjakan Fase 2 sebelum seluruh task P0 MVP selesai.
- Jangan menambah operasi hardcoded di inti. Semua operasi masuk `core.berp`
  atau plugin lain.
- Setiap dependency baru wajib dicatat alasannya di `ARCHITECTURE.md`.

## 1. Milestone

| Milestone | Cakupan | Feature |
|---|---|---|
| M0 — Fondasi | Struktur, dependency, dokumen kontrak | F00, F01 |
| M1 — Domain & Engine | Recipe model, pipeline, isolate | F02, F03 |
| M2 — Plugin & Runtime | Loader, hash, sandbox, DSL/Lua/WASM | F04, F05 |
| M3 — Data & UI dasar | Storage, tema, komponen, shell | F06, F07 |
| M4 — Fitur MVP | Home, editor, library, plugin manager, settings | F08–F12 |
| M5 — Core pack | Tooling paket + operasi `core.berp` | F13 |
| M6 — Pengerasan & rilis | Keamanan, QA, build | F14, F15 |

## 2. Baseline & gap yang diketahui (2026-11-11)

- Repo masih scaffold Flutter (`counter app`); hanya `lib/main.dart` dan
  `test/widget_test.dart` yang berisi kode aplikasi.
- `flutter analyze` bersih dan `flutter test` lulus pada baseline.
- `pubspec.yaml` belum memuat dependency arsitektur (Riverpod, SQLite,
  `wasm_run`, `crypto`, `archive`, `file_picker`, dll.).
- Folder `lib/core/`, `lib/features/`, dan `lib/assets/` belum ada.
- `core.berp` dan `lua_runtime.wasm` belum ada.
- `operations.md` dirujuk banyak dokumen tetapi belum dibuat.
- README menyebut folder `docs/`, padahal dokumen berada di root repo.
- Repo git belum memiliki commit awal.

---

## F00 — Fondasi Proyek & Dokumentasi

- [x] **F00-T01 (P0)** Scaffold struktur folder feature-first.
  - Buat `lib/core/{engine,plugin,runtime,storage,ui,error}`,
    `lib/features/{recipe,operations,library,plugins,settings}`,
    `lib/assets/`, dan `test/{core,features}` dengan `.gitkeep`.
  - Acceptance: struktur sesuai `ARCHITECTURE.md` §3; `flutter analyze`
    tetap bersih.
- [x] **F00-T02 (P0)** Tambahkan dependency inti beserta alasan.
  - Kandidat: `flutter_riverpod`, `crypto`, `archive`, `path_provider`,
    `sqflite`, `wasm_run`, `file_picker`; dev: `sqflite_common_ffi`.
  - Acceptance: `flutter pub get` sukses; tabel dependency + alasan +
    alternatif yang ditolak ditulis di `ARCHITECTURE.md`.
- [x] **F00-T03 (P0)** Perketat `analysis_options.yaml`.
  - Aktifkan lint relevan (mis. `always_declare_return_types`,
    `prefer_final_locals`, `avoid_print`, `use_super_parameters`).
  - Acceptance: `flutter analyze` tanpa issue.
- [x] **F00-T04 (P1)** CI dasar GitHub Actions: `flutter analyze` +
    `flutter test` pada push/PR.
- [x] **F00-T05 (P1)** Rapikan `README.md` dan lisensi.
  - Perbaiki referensi folder `docs/` (dokumen ada di root), perbarui
    status proyek, tambahkan `LICENSE` MIT untuk inti.
- [x] **F00-T06 (P0)** Buat `operations.md`.
  - Isi minimum: detail kontrak `Operation`, tipe parameter, format
    `OperationIO`, format error terstruktur, skema recipe v1, aturan
    contract test, dan katalog operasi core (boleh bertahap, dilengkapi
    di F13).
  - Acceptance: tidak ada lagi rujukan dokumen yang hilang; kontrak
    disetujui dan dipakai oleh test.
- [x] **F00-T07 (P0)** Bersihkan template Flutter.
  - Ganti `main.dart` menjadi entrypoint minimal (`ProviderScope` +
    placeholder app), hapus counter, ganti `widget_test.dart` menjadi
    smoke test aplikasi.
  - Acceptance: `flutter test` lulus; tidak ada kode contoh counter.

## F01 — Domain: Buffer, Error, Kontrak Operation

- [x] **F01-T01 (P0)** Model `Buffer` immutable.
  - Dukung tipe `text`, `bytes`, dan referensi file; konversi
    text↔bytes, encoding, batas ukuran, dan pemotongan preview.
  - Acceptance: unit test konversi, equality, dan preview pass.
- [x] **F01-T02 (P0)** Model error terstruktur (sealed class/Result).
  - Kategori: validation, plugin, runtime, permission, storage,
    unsupported, cancelled; bawa konteks `pluginId`, `stepId`, dan pesan
    ramah pengguna.
  - Acceptance: test mapping error ke pesan UI; tidak ada exception
    mentah yang bocor ke UI.
- [x] **F01-T03 (P0)** Model parameter operasi.
  - Tipe: string, int, bool, enum/select, dan validasi default/wajib.
  - Acceptance: test parsing, validasi, dan nilai default.
- [x] **F01-T04 (P0)** Kontrak `Operation`, `OperationIO`,
    `OperationCategory`, dan `OperationDescriptor`.
  - Sesuaikan dengan `ARCHITECTURE.md` §6; tambahkan `contractVersion`.
  - Acceptance: satu implementasi dummy lulus contract test harness.
- [x] **F01-T05 (P0)** `OperationRegistry` in-memory.
  - Registrasi, unregister, lookup by id, list by kategori, pencarian,
    dan filter plugin aktif.
  - Acceptance: test duplikasi ID dan operasi unsupported.
- [x] **F01-T06 (P0)** Contract test harness berbasis contoh I/O.
  - Satu skenario per operasi: input, args, output yang diharapkan,
    error yang diharapkan.
  - Acceptance: harness dapat dijalankan terhadap operasi dummy dan
    operasi `core.berp`.
- [x] **F01-T07 (P0)** Dokumentasikan versioning kontrak.
  - Aturan kenaikan versi kontrak dan kompatibilitas plugin lama.
  - Acceptance: tercatat di `operations.md` dan `ARCHITECTURE.md`.

## F02 — Model & Validasi Recipe

- [x] **F02-T01 (P0)** Model recipe v1.
  - `Recipe` (schemaVersion, id, name, steps, input, output, meta),
    `RecipeStep` (id, operationId, args, enabled), dan `RecipeMeta`.
  - Acceptance: model immutable + unit test.
- [x] **F02-T02 (P0)** Serialisasi JSON v1 (`fromJson`/`toJson`).
  - Validasi field wajib, tipe, dan nilai tak dikenal dengan pesan jelas.
  - Acceptance: round-trip test dan test JSON invalid.
- [x] **F02-T03 (P0)** Validasi recipe.
  - Step ID unik, operationId tidak kosong, args sesuai schema operasi
    (bila registry tersedia), minimal satu step.
  - Acceptance: test kasus valid/invalid.
- [x] **F02-T04 (P0)** Kerangka migrasi schema.
  - Registry migrasi per `schemaVersion`; v1 = no-op.
  - Acceptance: test menolak versi lebih baru dan menjalankan migrasi
    berantai.
- [x] **F02-T05 (P0)** Codec impor/ekspor `.brecipe` (JSON).
  - Batas ukuran file, validasi schema, dan error yang ramah.
  - Acceptance: test import/export round-trip.
- [x] **F02-T06 (P0)** Dokumentasikan skema recipe v1 di
    `operations.md` dan tautkan dari `ARCHITECTURE.md`.

## F03 — Recipe Engine & Pipeline Executor

- [x] **F03-T01 (P0)** Pipeline executor sekuensial.
  - `Buffer → step 1 → step 2 → … → output`; dispatch berdasarkan tier
    runtime.
  - Acceptance: test multi-step dengan operasi dummy.
- [x] **F03-T02 (P0)** Semantik step nonaktif dan unsupported.
  - `enabled=false` dilewati; operasi unsupported dilewati dengan
    peringatan, bukan crash.
  - Acceptance: test kedua kasus.
- [x] **F03-T03 (P0)** Error per step.
  - Bungkus error dengan `pluginId` + `stepId`; tentukan dan dokumentasikan
    kebijakan stop vs lanjut.
  - Acceptance: test error di tengah pipeline; UI tetap stabil.
- [ ] **F03-T04 (P0)** Eksekusi di isolate.
  - Protokol pesan request/response/progress; tidak memblokir UI.
  - Acceptance: test pipeline berat tetap responsif (fake UI ticker) dan
    data kompleks terkirim dengan benar.
- [x] **F03-T05 (P0)** Stream progres dan hasil live.
  - Kirim output antar-step; dukung pembatalan eksekusi.
  - Acceptance: test urutan event dan cancellation.
- [x] **F03-T06 (P0)** Integrasi batas waktu sandbox.
  - Timeout per step, error terstruktur, dan pembersihan isolate.
  - Acceptance: test operasi lambat dihentikan.
- [x] **F03-T07 (P0)** Test kontrak end-to-end pertama.
  - Recipe contoh (mis. `base64_decode`) berjalan dari `core.berp`
    (boleh memakai dummy sampai F13 selesai).
  - Acceptance: test pipeline + plugin loader + runtime pass.
- [x] **F03-T08 (P1)** Benchmark pipeline.
  - Ukur overhead isolate dan operasi berat; catat hasil di
    `progress.md`.

## F04 — Sistem Plugin

- [x] **F04-T01 (P0)** Model + parser `plugin.manifest.json`.
  - Validasi `manifestVersion`, `pluginId`, semver, tier, entrypoint
    relatif, permissions, operations, dan `minAppVersion`.
  - Acceptance: test manifest valid/invalid.
- [x] **F04-T02 (P0)** Pembaca paket `.berp` (zip) yang aman.
  - Tolak path traversal, symlink, jumlah entri/ukuran berlebih, dan
    entrypoint di luar root.
  - Acceptance: test zip-slip, zip bomb kecil, dan paket valid.
- [x] **F04-T03 (P0)** Verifikator SHA-256.
  - Hitung hash paket/entrypoint, bandingkan dengan hash pin/registry/
    input pengguna; mismatch = tolak.
  - Acceptance: test paket dimodifikasi ditolak.
- [x] **F04-T04 (P0)** Model plugin terpasang + status.
  - Metadata: id, versi, tier, permissions, source
    (core/registry/sideload), verified/unverified, enabled.
  - Acceptance: test serialisasi dan aturan kompatibilitas versi app.
- [ ] **F04-T05 (P0)** Alur sideload.
  - Pilih file → preview manifest → consent izin → verifikasi hash →
    ekstrak atomik → daftarkan operasi; bersihkan sisa saat gagal.
  - Acceptance: test instal sukses, hash mismatch, dan izin ditolak.
- [x] **F04-T06 (P0)** Siklus hidup plugin.
  - Enable/disable/hapus; operasi ikut keluar/masuk registry; peringatan
    saat menghapus/menonaktifkan `core.berp`.
  - Acceptance: test operasi hilang dari picker setelah disable.
- [x] **F04-T07 (P0)** Model izin/capability.
  - `cpu`, `net`, `file:read`, `file:write`; consent persist; hook
    enforcement untuk runtime.
  - Acceptance: test panggilan tanpa izin menghasilkan error terstruktur.
- [ ] **F04-T08 (P0)** Bootstrap `core.berp`.
  - Muat aset → verifikasi hash pin → instal first-run → daftarkan
    operasi; bila gagal tampilkan error jelas dan app tetap terbuka.
  - Acceptance: test first-run, already-installed, dan hash mismatch.
- [x] **F04-T09 (P0)** Registrasi operasi dari manifest.
  - Petakan metadata manifest ke `OperationDescriptor`; tangani tier tak
    didukung dan ID duplikat dengan peringatan.
  - Acceptance: test deskripsi operasi muncul di registry.
- [ ] **F04-T10 (P0)** `PluginManagerService` + provider Riverpod.
  - Orkestrasi instal, verifikasi, enable/disable, hapus, dan bootstrap.
  - Acceptance: test service dengan storage in-memory.
- [x] **F04-T11 (P0)** Test adversarial paket plugin.
  - Manifest palsu, entrypoint hilang, hash salah, izin tak dikenal.

## F05 — Runtime & Sandbox

- [x] **F05-T01 (P0)** Kontrak sandbox dan konfigurasi resource.
  - Batas waktu, memori, izin aktif, dan konteks eksekusi.
  - Acceptance: test konfigurasi default dan override.
- [ ] **F05-T02 (P0)** Runtime DSL.
  - Definisikan skema JSON/YAML: mapping, regex replace, konversi unit,
    rename; regex aman dengan timeout.
  - Acceptance: test tiap transformasi + input invalid.
- [ ] **F05-T03 (P0)** Siapkan `lua_runtime.wasm`.
  - Finalisasi interpreter (lihat keputusan D02), catat lisensi, simpan
    aset, dan pin SHA-256.
  - Acceptance: hash terdokumentasi dan cocok dengan file aset.
- [ ] **F05-T04 (P0)** Verifikasi + instantiasi runtime Lua via
    `wasm_run` di isolate.
  - Hash mismatch = tolak eksekusi dengan pesan jelas.
  - Acceptance: test hash mismatch dan runtime valid.
- [ ] **F05-T05 (P0)** Host API Lua yang terbatas.
  - Entrypoint `transform(input, args)`; stdlib tanpa `os`, `io`,
    `package`, `debug`; akses net/fs hanya lewat izin.
  - Acceptance: test script mencoba akses terlarang → error terstruktur.
- [ ] **F05-T06 (P0)** Runtime WASM untuk plugin tier `wasm`.
  - ABI input/output, tanpa host function net/fs kecuali izin.
  - Acceptance: test modul WASM contoh berjalan dan akses terlarang
    diblokir.
- [ ] **F05-T07 (P0)** Penegakan izin di semua runtime.
  - Pemeriksaan sebelum side effect; pesan error jelas.
  - Acceptance: test matrix runtime × izin.
- [ ] **F05-T08 (P1)** Cache dan disposal runtime.
  - Hindari instansiasi ulang berlebihan; bersihkan memori setelah idle.
- [ ] **F05-T09 (P0)** Contract test lintas runtime.
  - Operasi yang sama (contoh) dijalankan di DSL, Lua, dan WASM dengan
    hasil setara.

## F06 — Storage

- [ ] **F06-T01 (P0)** Inisialisasi SQLite + migrasi v1.
  - Tabel: recipe, plugin, setting, favorite, plugin_permission.
  - Acceptance: test buka DB, migrasi, dan reopen.
- [ ] **F06-T02 (P0)** `RecipeRepository`.
  - CRUD, urut berdasarkan update terakhir, pencarian nama.
  - Acceptance: test CRUD + ordering.
- [ ] **F06-T03 (P0)** `PluginRepository`.
  - Simpan metadata terpasang, status enable, source, verified.
  - Acceptance: test persist dan reload.
- [ ] **F06-T04 (P0)** `SettingsRepository`.
  - Tema, batas sandbox, opt-in log; nilai default aman.
  - Acceptance: test baca/tulis dan fallback default.
- [ ] **F06-T05 (P0)** `FavoriteRepository` untuk operasi favorit.
- [ ] **F06-T06 (P0)** Penyimpanan paket plugin di filesystem.
  - Direktori per plugin + versi, penulisan atomik, pembersihan saat
    uninstall/gagal.
- [ ] **F06-T07 (P0)** Test storage dengan `sqflite_common_ffi`.
  - Jalankan di CI tanpa device.

## F07 — UI Foundation & Design System

- [ ] **F07-T01 (P0)** Token desain + tema light/dark.
  - Warna, spacing, radius, tipografi sesuai `DESIGN.md` §2–4; font Inter
    dengan fallback sistem (lihat D04).
  - Acceptance: widget test memastikan warna/tema utama benar.
- [ ] **F07-T02 (P0)** Provider tema (system/light/dark) persisten.
- [ ] **F07-T03 (P0)** App shell + bottom navigation 3 tab
  (Home, Library, Settings) dengan state terjaga.
- [ ] **F07-T04 (P0)** Komponen tombol (primary, secondary, ghost,
  danger) dan badge (tier, status, unverified).
- [ ] **F07-T05 (P0)** Komponen kartu step operasi.
  - Drag handle, nama + kategori, toggle enabled, chevron, state
    disabled/error/unsupported.
- [ ] **F07-T06 (P0)** Komponen buffer panel input/output.
  - Header, mode mono, copy, expand, empty state, indikator live, banner
    error.
- [ ] **F07-T07 (P0)** Komponen empty state reusable.
- [ ] **F07-T08 (P0)** Dialog izin (tidak bisa ditutup via tap luar).
- [ ] **F07-T09 (P0)** Toast/snackbar dengan varian info/success/
  warning/error dan aksi undo.
- [ ] **F07-T10 (P0)** Audit aksesibilitas dasar.
  - Target sentuh 44dp, label semantik, kontras, text scaling 1.3x.
  - Acceptance: widget test text scale + manual checklist DESIGN §15.

## F08 — Fitur Home

- [ ] **F08-T01 (P0)** Provider daftar recipe (recent + search).
- [ ] **F08-T02 (P0)** UI Home sesuai wireframe DESIGN §8.1.
- [ ] **F08-T03 (P0)** Empty state "Belum ada recipe" + aksi buat baru.
- [ ] **F08-T04 (P0)** Hapus/duplikasi recipe dengan konfirmasi + undo.
- [ ] **F08-T05 (P0)** Navigasi ke Recipe Editor (baru/terpilih).
- [ ] **F08-T06 (P0)** Widget test Home: list, search, empty, hapus.

## F09 — Fitur Recipe Editor

- [ ] **F09-T01 (P0)** Layout editor: nama, input panel, daftar step,
  output panel, aksi simpan.
- [ ] **F09-T02 (P0)** Tambah step lewat Operation Picker.
- [ ] **F09-T03 (P0)** Reorder drag and drop + haptic.
- [ ] **F09-T04 (P0)** Enable/disable dan hapus step (undo).
- [ ] **F09-T05 (P0)** Sheet konfigurasi parameter per tipe + validasi.
- [ ] **F09-T06 (P0)** Preview live dengan debounce 200 ms.
  - Batalkan eksekusi lama saat input berubah.
- [ ] **F09-T07 (P0)** Tampilan error per step dan badge unsupported.
- [ ] **F09-T08 (P0)** Simpan, rename, dan guard perubahan belum
  tersimpan.
- [ ] **F09-T09 (P0)** Impor/ekspor `.brecipe` dari editor.
- [ ] **F09-T10 (P1)** Input dari file (scoped, tanpa streaming besar).
- [ ] **F09-T11 (P0)** Widget test alur: tambah step, reorder, disable,
  live output, simpan, error step.

## F10 — Fitur Library & Operation Picker

- [ ] **F10-T01 (P0)** Provider operasi dari plugin aktif (gabungan
  registry + metadata plugin).
- [ ] **F10-T02 (P0)** Operation Picker bottom sheet 85% layar.
  - Search sticky, chip kategori, daftar operasi + badge tier, tap untuk
    menambah.
- [ ] **F10-T03 (P0)** Pencarian dan filter kategori/favorit.
- [ ] **F10-T04 (P0)** Favorit operasi (persist).
- [ ] **F10-T05 (P0)** Tab Library: daftar operasi + pencarian + detail
  singkat.
- [ ] **F10-T06 (P0)** Empty state tanpa plugin → arahkan ke Plugin
  Manager/sideload, bukan error.
- [ ] **F10-T07 (P0)** Widget test picker dan library.

## F11 — Fitur Plugin Manager

- [ ] **F11-T01 (P0)** Daftar plugin (core/komunitas) dengan versi, tier,
  izin, sumber, status, badge unverified.
- [ ] **F11-T02 (P0)** Halaman detail plugin: manifest, izin, operasi,
  ukuran, sumber.
- [ ] **F11-T03 (P0)** Aksi enable/disable/hapus dengan konfirmasi dan
  peringatan core.
- [ ] **F11-T04 (P0)** Alur sideload UI: pilih file → preview manifest →
  dialog izin → hasil.
- [ ] **F11-T05 (P0)** Integrasi dialog izin untuk `net`, `file:read`,
  `file:write`.
- [ ] **F11-T06 (P1)** Tombol katalog + peringatan akses jaringan;
  tampilkan "belum tersedia" sampai registry Fase 2.
- [ ] **F11-T07 (P0)** State kegagalan bootstrap `core.berp` + aksi
  reinstalasi, app tetap bisa dibuka.
- [ ] **F11-T08 (P0)** Empty state Plugin Manager.
- [ ] **F11-T09 (P0)** Widget test alur sideload (mock file picker),
  enable/disable, dan detail.

## F12 — Fitur Settings

- [ ] **F12-T01 (P0)** Pilihan tema (system/light/dark) persisten.
- [ ] **F12-T02 (P1)** Pengaturan sandbox: batas waktu dan memori
  (dengan nilai default aman).
- [ ] **F12-T03 (P1)** Opt-in log eksekusi plugin + hapus log.
- [ ] **F12-T04 (P0)** Tentang aplikasi: versi, lisensi, kebijakan
  privasi offline.
- [ ] **F12-T05 (P1)** Reinstalasi `core.berp` dan reset data dengan
  konfirmasi.
- [ ] **F12-T06 (P0)** Widget test Settings.

## F13 — core.berp: Tooling & Operasi

### Tooling & format

- [ ] **F13-T01 (P0)** Spesifikasi authoring operasi core.
  - Struktur source `plugins/core/`, manifest per operasi/paket, format
    DSL/Lua/WASM, dan aturan ID stabil.
- [ ] **F13-T02 (P0)** Build script `.berp`.
  - Bungkus zip deterministik, hitung SHA-256, hasilkan hash untuk di-pin
    ke aplikasi.
- [ ] **F13-T03 (P0)** Test integritas build.
  - Hash aset `core.berp` harus cocok dengan pin; build ulang harus
    deterministik.

### Paket operasi

- [ ] **F13-T04 (P0)** Operasi Encode/Decode dasar.
  - Base64 encode/decode, Base32 decode/encode, Hex encode/decode, URL
    encode/decode, HTML entity encode/decode.
  - Setiap operasi: manifest, contoh I/O, contract test, entri
    `operations.md`, lisensi.
- [ ] **F13-T05 (P0)** Operasi hash/kripto dasar.
  - MD5, SHA-1, SHA-256, SHA-512 (hash); util HMAC-SHA256.
  - Catat bahwa MD5/SHA-1 untuk kompatibilitas, bukan keamanan.
- [ ] **F13-T06 (P0)** Operasi Format.
  - JSON prettify/minify, JWT decode (tanpa verifikasi klaim), XML
    prettify bila memungkinkan.
- [ ] **F13-T07 (P1)** Operasi Analysis.
  - Entropy, frequency, magic bytes/file type, ekstraksi string.
- [ ] **F13-T08 (P0)** Operasi Utility.
  - Upper/lower/title case, reverse, find & replace, regex replace,
    slice, sort lines, unique lines.
- [ ] **F13-T09 (P1)** Operasi kripto lanjutan.
  - AES encrypt/decrypt, XOR, HMAC varian; hanya setelah review
    keamanan.
- [ ] **F13-T10 (P0)** Audit lisensi semua operasi yang diadaptasi.
  - Catat sumber, lisensi, dan atribusi di manifest/README paket.
- [ ] **F13-T11 (P1)** Ukuran paket dan lazy load.
  - Ukur ukuran `core.berp`, terapkan kompresi/pemisahan paket bila
    melebihi target.

## F14 — Keamanan & Kualitas

- [ ] **F14-T01 (P0)** Threat model singkat (aset, aktor, jalur serang,
  mitigasi).
- [ ] **F14-T02 (P0)** Test adversarial paket & filesystem.
  - Zip-slip, zip bomb, symlink, path absolut, ukuran berlebih.
- [ ] **F14-T03 (P0)** Test bypass izin.
  - Net/fs dari DSL, Lua, dan WASM tanpa consent harus gagal.
- [ ] **F14-T04 (P0)** Keamanan regex.
  - Timeout/batas panjang untuk mencegah ReDoS di DSL dan utility.
- [ ] **F14-T05 (P0)** CSPRNG untuk operasi acak.
- [ ] **F14-T06 (P0)** Audit "offline by default".
  - Pastikan tidak ada dependency/fungsi jaringan yang aktif tanpa aksi
    pengguna.
- [ ] **F14-T07 (P0)** Integration test end-to-end.
  - Bootstrap → sideload plugin → buat recipe multi-step → simpan →
    ekspor → impor → jalankan.
- [ ] **F14-T08 (P1)** Uji performa dan memori.
  - Input besar (sesuai batas MVP), tidak OOM, UI tetap responsif.
- [ ] **F14-T09 (P0)** QA desain.
  - Checklist `DESIGN.md` §15: dark mode, layar kecil/besar, text scale,
    empty state, aksesibilitas.

## F15 — Rilis MVP

- [ ] **F15-T01 (P0)** Metadata aplikasi: nama, deskripsi, ikon, splash,
  application ID.
- [ ] **F15-T02 (P0)** Konfigurasi Android/iOS.
  - Min SDK, izin platform minimal (tanpa INTERNET default), signing
    build lokal (tidak di-commit).
- [ ] **F15-T03 (P0)** Teks privasi offline + lisensi pihak ketiga.
- [ ] **F15-T04 (P0)** Versi rilis `1.0.0+1` dan changelog rilis.
- [ ] **F15-T05 (P0)** Smoke test build Android di device/emulator.
- [ ] **F15-T06 (P0)** Jalankan seluruh checklist `AGENT.md` §7 dan
  `ROADMAP.md` Fase 1.
- [ ] **F15-T07 (P0)** Commit rilis + tag lokal `v1.0.0` (tanpa push).

---

## F16 — Backlog Fase 2 (P2, setelah MVP)

- [ ] **F16-T01** Registry resmi read-only + `registry.json` client.
- [ ] **F16-T02** UI katalog plugin + peringatan akses jaringan + cache.
- [ ] **F16-T03** Signature Ed25519 wajib untuk registry resmi.
- [ ] **F16-T04** Plugin update/rollback + notifikasi versi.
- [ ] **F16-T05** Streaming file besar tanpa OOM.
- [ ] **F16-T06** Log eksekusi opt-in + layar diagnostik.
- [ ] **F16-T07** Audit/fuzzing sandbox dan runtime WASM.
- [ ] **F16-T08** Tooling registry (validasi, review checklist, publikasi).

## F17 — Backlog Fase 3 (P2)

- [ ] **F17-T01** Marketplace plugin (kurasi, rating, laporan).
- [ ] **F17-T02** Kolaborasi recipe (share/fork/komentar) opt-in.
- [ ] **F17-T03** AI assistant opsional untuk menyusun recipe.
- [ ] **F17-T04** Dukungan desktop/web.
- [ ] **F17-T05** Integrasi share sheet dan automation.

---

## D — Keputusan yang Harus Diambil Manusia

- [ ] **D01** Finalisasi ruang lingkup "hampir semua operasi CyberChef"
  untuk MVP (daftar operasi P0 vs pasca-MVP).
- [ ] **D02** Pilih interpreter Lua yang dikompilasi ke WASM (omnilua atau
  alternatif) + lisensi.
- [ ] **D03** Tentukan ukuran maksimum `core.berp` dan strategi lazy load.
- [ ] **D04** Finalisasi font: Inter dibundel vs system font.
- [ ] **D05** Konfirmasi lisensi MIT untuk inti dan `core.berp`.
- [ ] **D06** Kebijakan error pipeline: berhenti di step error atau lanjut
  dengan output terakhir + peringatan.
- [ ] **D07** Target waktu rilis MVP.
- [ ] **D08** Finalisasi skema DSL (field, operator, dan batas keamanan).
- [ ] **D09** Strategi cache runtime untuk banyak plugin.
- [ ] **D10** Apakah plugin DSL dibungkus `.berp` (rekomendasi: ya).
