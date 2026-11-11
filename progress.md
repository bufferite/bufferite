# progress.md — Bufferite Progress Checkpoints

Versi: 1.0
Terakhir diperbarui: 2026-11-11
Sumber daftar task: [TODO.md](TODO.md)

---

## 1. Cara Pakai

1. Ambil task berikutnya dari `TODO.md` sesuai urutan dependency.
2. Saat task selesai: centang `[x]` di `TODO.md`.
3. Tambahkan **satu baris** di tabel "Task Selesai" (§5) berisi ID, ringkasan,
   file yang disentuh, hasil verifikasi, dan commit.
4. Perbarui snapshot (§3) dan tambahkan entri di "Riwayat Checkpoint" (§6).
5. Task hanya boleh ditandai selesai jika memenuhi `AGENT.md` §9.

Status yang dipakai:

- `Belum` — belum dikerjakan.
- `Berjalan` — sedang dikerjakan.
- `Selesai` — sudah memenuhi Definisi Done.
- `Blocked` — menunggu keputusan/dependency (catat alasannya).
- `Dibatalkan` — tidak lagi relevan (catat alasannya).

## 2. Snapshot Saat Ini

| Item | Nilai |
|---|---|
| Fase aktif | Fase 0 — Fondasi |
| Milestone aktif | M0 — Fondasi |
| Task MVP selesai | 20 / 131 |
| Task Fase 2 | 0 / 8 |
| Task Fase 3 | 0 / 5 |
| Keputusan terbuka | 10 |
| Task sedang berjalan | — |
| Task berikutnya | `F03-T01` — pipeline executor |
| Blocker aktif | Tidak ada |
| Analyze | Lulus (0 issue, 2026-11-11) |
| Test suite | Lulus (70 test, 2026-11-11) |

## 3. Progres per Feature

Angka "Selesai" hanya bertambah setelah checkpoint dicatat di §5.

| Feature | Total | Selesai | Status |
|---|---:|---:|---|
| F00 — Fondasi Proyek & Dokumentasi | 7 | 7 | Selesai |
| F01 — Domain: Buffer, Error, Kontrak Operation | 7 | 7 | Selesai |
| F02 — Model & Validasi Recipe | 6 | 6 | Selesai |
| F03 — Recipe Engine & Pipeline Executor | 8 | 0 | Belum |
| F04 — Sistem Plugin | 11 | 0 | Belum |
| F05 — Runtime & Sandbox | 9 | 0 | Belum |
| F06 — Storage | 7 | 0 | Belum |
| F07 — UI Foundation & Design System | 10 | 0 | Belum |
| F08 — Fitur Home | 6 | 0 | Belum |
| F09 — Fitur Recipe Editor | 11 | 0 | Belum |
| F10 — Fitur Library & Operation Picker | 7 | 0 | Belum |
| F11 — Fitur Plugin Manager | 9 | 0 | Belum |
| F12 — Fitur Settings | 6 | 0 | Belum |
| F13 — core.berp: Tooling & Operasi | 11 | 0 | Belum |
| F14 — Keamanan & Kualitas | 9 | 0 | Belum |
| F15 — Rilis MVP | 7 | 0 | Belum |
| **Total MVP** | **131** | **20** | **Berjalan** |
| F16 — Backlog Fase 2 | 8 | 0 | Belum |
| F17 — Backlog Fase 3 | 5 | 0 | Belum |
| D — Keputusan Manusia | 10 | 0 | Terbuka |

## 4. Ringkasan Baseline (2026-11-11)

Audit awal repo sebelum implementasi:

- Flutter 3.44.8 / Dart 3.12.2 terpasang.
- `flutter analyze` → **No issues found**.
- `flutter test` → **1 test lulus** (smoke test counter template).
- Kode aplikasi masih template Flutter: `lib/main.dart` (counter) dan
  `test/widget_test.dart`.
- Dependency masih minimal: `cupertino_icons`, `flutter_lints`.
- Belum ada folder `lib/core/`, `lib/features/`, `lib/assets/`.
- Belum ada `core.berp`, `lua_runtime.wasm`, atau build tooling paket.
- `operations.md` belum ada meskipun dirujuk `AGENT.md`,
  `ARCHITECTURE.md`, `PLUGINS.md`, dan `ROADMAP.md`.
- `README.md` menyebut folder `docs/`, padahal dokumen berada di root.
- Repo git belum memiliki commit; seluruh file masih untracked.
- Dokumen produk lengkap dan konsisten: `README`, `AGENT`, `ARCHITECTURE`,
  `PLUGINS`, `DESIGN`, `ROADMAP`, `CONTRIBUTING`.

Kesimpulan: proyek berada di **akhir Fase 0 perencanaan / awal
implementasi**. Fondasi kode belum dimulai; langkah pertama adalah F00.

## 5. Task Selesai

Tabel checkpoint per task. Satu baris per task yang sudah dicentang di
`TODO.md`.

| Tanggal | ID | Ringkasan | File utama | Verifikasi | Commit |
|---|---|---|---|---|---|
| 2026-11-11 | F00-T01 | Scaffold folder feature-first + `.gitkeep` | `lib/core/**`, `lib/features/**`, `test/**` | `flutter analyze` → 0 issue | `6d9e175` |
| 2026-11-11 | F00-T02 | Dependency inti + alasan dan alternatif | `pubspec.yaml`, `pubspec.lock`, `ARCHITECTURE.md` | `flutter pub get` sukses; `flutter analyze` → 0 issue | `6d9e175` |
| 2026-11-11 | F00-T03 | Perketat lint & strict analyzer | `analysis_options.yaml` | `flutter analyze` → 0 issue | `6d9e175` |
| 2026-11-11 | F00-T04 | CI analyze + test | `.github/workflows/ci.yaml` | Workflow ditinjau; belum dijalankan karena belum push | `6d9e175` |
| 2026-11-11 | F00-T05 | README diperbaiki, LICENSE MIT, deskripsi paket | `README.md`, `LICENSE`, `pubspec.yaml` | Review manual; referensi `docs/` dihapus | `6d9e175` |
| 2026-11-11 | F00-T06 | Kontrak Operation, error, skema recipe v1 | `operations.md`, `ARCHITECTURE.md` | Review dokumen; kontrak dirujuk F01 | `6d9e175` |
| 2026-11-11 | F00-T07 | Template counter dihapus, smoke test baru | `lib/main.dart`, `test/widget_test.dart` | `flutter test` → 1 pass | `6d9e175` |
| 2026-11-11 | F01-T01 | Model `Buffer` immutable (text/bytes/file) + JSON | `lib/core/engine/buffer.dart`, `test/core/buffer_test.dart` | `flutter test` → 47 pass | `5d5df23` |
| 2026-11-11 | F01-T02 | `AppError` terstruktur + `Result`/`Ok`/`Err` | `lib/core/error/*.dart`, `test/core/app_error_result_test.dart` | `flutter test` → 47 pass | `5d5df23` |
| 2026-11-11 | F01-T03 | Parameter operasi + validasi/default | `lib/core/plugin/operation_param.dart`, `test/core/operation_param_test.dart` | `flutter test` → 47 pass | `5d5df23` |
| 2026-11-11 | F01-T04 | Kontrak `Operation`, IO, kategori, tier, descriptor | `lib/core/plugin/operation.dart` | `flutter analyze` → 0 issue | `5d5df23` |
| 2026-11-11 | F01-T05 | `OperationRegistry` + availability/duplikasi | `lib/core/plugin/operation_registry.dart`, `test/core/operation_registry_test.dart` | `flutter test` → 47 pass | `5d5df23` |
| 2026-11-11 | F01-T06 | Contract test harness + fake operation | `test/core/support/*`, `test/core/operation_contract_test.dart` | `flutter test` → 47 pass | `5d5df23` |
| 2026-11-11 | F01-T07 | Versioning kontrak didokumentasikan | `operations.md` §12, `ARCHITECTURE.md` §6 | Review dokumen | `5d5df23` |
| 2026-11-11 | F02-T01 | Model `Recipe`, `RecipeStep`, `RecipeMeta` v1 | `lib/features/recipe/recipe.dart` | `flutter test` → 70 pass | `32b8760` |
| 2026-11-11 | F02-T02 | Serialisasi JSON + validasi field | `lib/features/recipe/recipe.dart`, `test/features/recipe/recipe_test.dart` | `flutter test` → 70 pass | `32b8760` |
| 2026-11-11 | F02-T03 | Validasi recipe, step, dan args via registry | `lib/features/recipe/recipe.dart` | `flutter test` → 70 pass | `32b8760` |
| 2026-11-11 | F02-T04 | Kerangka migrasi schema (berantai) | `lib/features/recipe/recipe_codec.dart` | `flutter test` → 70 pass | `32b8760` |
| 2026-11-11 | F02-T05 | Codec impor/ekspor `.brecipe` + batas 5 MiB | `lib/features/recipe/recipe_codec.dart`, `test/features/recipe/recipe_codec_test.dart` | `flutter test` → 70 pass | `32b8760` |
| 2026-11-11 | F02-T06 | Dokumentasi skema & implementasi recipe | `operations.md` §8, `ARCHITECTURE.md` §7 | Review dokumen | `32b8760` |

Format verifikasi: perintah yang dijalankan + hasil, mis.
`flutter test (12 pass)`, `manual: sideload sukses`, atau
`analyze: 0 issue`.

## 6. Riwayat Checkpoint

### CP-000 — 2026-11-11 — Baseline audit

- Membaca seluruh dokumen proyek: `README`, `AGENT`, `ARCHITECTURE`,
  `PLUGINS`, `DESIGN`, `ROADMAP`, `CONTRIBUTING`.
- Menginventarisasi kode aktual: hanya template Flutter.
- Menjalankan baseline `flutter analyze` (bersih) dan `flutter test`
  (1 test lulus).
- Tidak ada perubahan kode.

### CP-001 — 2026-11-11 — Perencanaan task

- Membuat `TODO.md`: 131 task MVP (F00–F15), 13 task pasca-MVP (F16–F17),
  dan 10 keputusan terbuka (D).
- Membuat `progress.md` sebagai checkpoint progres.
- Menyimpan seluruh pekerjaan ke git (commit lokal, tanpa push).
- Status implementasi tetap 0/131.

### CP-002 — 2026-11-11 — F00 Fondasi Proyek & Dokumentasi

- Status: Selesai (7/7 task F00).
- Perubahan:
  - Struktur folder feature-first dan folder test dibuat.
  - Dependency inti ditambahkan; `cupertino_icons` dihapus karena belum
    dipakai. Alasan dependency dicatat di `ARCHITECTURE.md` §12.
  - Lint diperketat + analyzer strict; template counter diganti app
    placeholder dengan `ProviderScope`.
  - `operations.md` dibuat (kontrak, error, skema recipe v1, test kontrak).
  - README diperbaiki, LICENSE MIT, CI dasar ditambahkan.
- File: `lib/main.dart`, `test/widget_test.dart`, `pubspec.yaml`,
  `pubspec.lock`, `analysis_options.yaml`, `operations.md`,
  `ARCHITECTURE.md`, `README.md`, `LICENSE`, `.github/workflows/ci.yaml`.
- Verifikasi:
  - `dart format lib test` → 2 file diformat.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **1 test lulus**.
- Catatan/risiko: CI belum dijalankan karena repo belum di-push; akan
  tervalidasi saat remote tersedia. `operations.md` memakai kebijakan error
  stop sementara sambil menunggu D06.
- Commit: `6d9e175` (kode/dokumen) + commit checkpoint ini.

### CP-003 — 2026-11-11 — F01 Domain & Kontrak Operation

- Status: Selesai (7/7 task F01).
- Perubahan:
  - Model `Buffer` sealed: text, bytes, file; JSON codec, preview, dan
    proteksi immutability.
  - `AppError` + `Result`/`Ok`/`Err` sebagai jalur error tanpa exception
    mentah ke UI.
  - Parameter operasi (string/integer/boolean/select), default, validasi,
    serta penolakan argumen tak dikenal.
  - Kontrak `Operation`, `OperationIO`, kategori, tier runtime, dan
    `OperationDescriptor` dengan versioning kontrak.
  - `OperationRegistry` in-memory: registrasi, pencarian, duplikasi,
    availability, dan status unsupported.
  - Contract test harness reusable + operasi palsu (reverse, Base64 decode).
- File: `lib/core/engine/buffer.dart`, `lib/core/error/app_error.dart`,
  `lib/core/error/result.dart`, `lib/core/plugin/operation.dart`,
  `lib/core/plugin/operation_param.dart`,
  `lib/core/plugin/operation_registry.dart`, dan 5 file test core + support.
- Verifikasi:
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **47 test lulus**.
- Catatan/risiko: kebijakan error pipeline masih menunggu D06; kontrak sudah
  menyediakan kode error `unsupported` dan konteks `pluginId`/`stepId`.
- Commit: `5d5df23` (kode/test) + commit checkpoint ini.

### CP-004 — 2026-11-11 — F02 Model & Validasi Recipe

- Status: Selesai (6/6 task F02).
- Perubahan:
  - Model `Recipe`, `RecipeStep`, `RecipeMeta` immutable + JSON v1.
  - Validasi ID UUID v4, nama, jumlah step, step ID unik, operationId,
    args terhadap registry, dan penolakan input file untuk `.brecipe`.
  - Codec `.brecipe`: batas 5 MiB, migrasi schema berantai, validasi sebelum
    dipakai, output cache tidak diekspor.
  - Dokumentasi skema dan lokasi implementasi diperbarui.
- File: `lib/features/recipe/recipe.dart`,
  `lib/features/recipe/recipe_codec.dart`, test recipe, `ARCHITECTURE.md`.
- Verifikasi:
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **70 test lulus**.
- Catatan/risiko: migrasi v1 belum punya langkah nyata (v1 = versi saat ini);
  kerangka sudah diuji dengan skenario v0 → v1.
- Commit: `32b8760` (kode/test) + commit checkpoint ini.

## 7. Template Checkpoint Baru

Salin format berikut saat menyelesaikan task:

```md
### CP-XXX — YYYY-MM-DD — FNN-TNN <judul singkat>

- Status: Selesai
- Perubahan: <ringkasan 1–3 poin>
- File: <path utama>
- Verifikasi: `<perintah>` → <hasil>
- Catatan/risiko: <jika ada>
- Commit: `<hash>`
```

Dan tambahkan baris di §5 serta perbarui angka di §2 dan §3.

## 8. Blocker & Keputusan Tertunda

Catat blocker di sini agar tidak menebak. Rujuk ID keputusan di `TODO.md`
bagian D.

| Tanggal | Terkait | Blocker/Keputusan | Dampak | Status |
|---|---|---|---|---|
| 2026-11-11 | D01, F13 | Ruang lingkup operasi `core.berp` belum final | Menentukan jumlah operasi MVP | Terbuka |
| 2026-11-11 | D02, F05-T03 | Interpreter Lua via WASM belum dipilih | Menunda runtime Lua | Terbuka |
| 2026-11-11 | F00-T06 | `operations.md` belum ada | Kontrak Operation belum tertulis | Selesai (F00-T06) |
| 2026-11-11 | D06, F03-T03 | Kebijakan stop vs lanjut saat error step | Memengaruhi UI dan test engine | Terbuka |
| 2026-11-11 | D07 | Target rilis MVP belum ditetapkan | Prioritas task belum berbatas waktu | Terbuka |

## 9. Catatan Keputusan (diisi saat ada)

| Tanggal | ID | Keputusan | Alasan | Dampak |
|---|---|---|---|---|
| — | — | — | — | — |
