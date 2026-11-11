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
| Fase aktif | Fase 1 — MVP |
| Milestone aktif | M1 — Domain & Engine |
| Task MVP selesai | 46 / 131 |
| Task Fase 2 | 0 / 8 |
| Task Fase 3 | 0 / 5 |
| Keputusan terbuka | 10 |
| Task sedang berjalan | — |
| Task berikutnya | `F07-T04` — komponen tombol + badge |
| Blocker aktif | F03-T04 host isolate; F05-T02/D08; F05-T03/D02 |
| Analyze | Lulus (0 issue, 2026-11-11) |
| Test suite | Lulus (190 test, 2026-11-11) |

## 3. Progres per Feature

Angka "Selesai" hanya bertambah setelah checkpoint dicatat di §5.

| Feature | Total | Selesai | Status |
|---|---:|---:|---|
| F00 — Fondasi Proyek & Dokumentasi | 7 | 7 | Selesai |
| F01 — Domain: Buffer, Error, Kontrak Operation | 7 | 7 | Selesai |
| F02 — Model & Validasi Recipe | 6 | 6 | Selesai |
| F03 — Recipe Engine & Pipeline Executor | 8 | 7 | Sebagian (T04 blocked) |
| F04 — Sistem Plugin | 11 | 8 | Sebagian (T05/T08/T10 ditunda) |
| F05 — Runtime & Sandbox | 9 | 1 | Sebagian (T02/T03 blocked) |
| F06 — Storage | 7 | 7 | Selesai |
| F07 — UI Foundation & Design System | 10 | 3 | Berjalan |
| F08 — Fitur Home | 6 | 0 | Belum |
| F09 — Fitur Recipe Editor | 11 | 0 | Belum |
| F10 — Fitur Library & Operation Picker | 7 | 0 | Belum |
| F11 — Fitur Plugin Manager | 9 | 0 | Belum |
| F12 — Fitur Settings | 6 | 0 | Belum |
| F13 — core.berp: Tooling & Operasi | 11 | 0 | Belum |
| F14 — Keamanan & Kualitas | 9 | 0 | Belum |
| F15 — Rilis MVP | 7 | 0 | Belum |
| **Total MVP** | **131** | **46** | **Berjalan** |
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
| 2026-11-11 | F03-T01 | Pipeline executor sekuensial + dispatch registry | `lib/core/engine/pipeline.dart`, `lib/core/engine/pipeline_executor.dart`, `test/core/pipeline_executor_test.dart` | `flutter test` → 85 pass | `6ef767e` |
| 2026-11-11 | F03-T02 | Skip step disabled dan operasi unsupported + warning | `lib/core/engine/pipeline_executor.dart` | `flutter test` → 85 pass | `6ef767e` |
| 2026-11-11 | F03-T03 | Error per step dengan `pluginId`/`stepId`; policy stop & lanjut | `lib/core/engine/pipeline_executor.dart`, `operations.md` §6 | `flutter test` → 85 pass | `6ef767e` |
| 2026-11-11 | F03-T05 | Stream event live, output antar-step, dan pembatalan best-effort | `lib/core/engine/pipeline.dart`, `lib/core/engine/pipeline_executor.dart` | `flutter test` → 85 pass | `6ef767e` |
| 2026-11-11 | F03-T06 | Timeout per step + error `runtime.timeout` | `lib/core/engine/pipeline_executor.dart` | `flutter test` → 85 pass | `6ef767e` |
| 2026-11-11 | F03-T07 | E2E dummy recipe → registry → pipeline | `lib/features/recipe/recipe_pipeline.dart`, `test/features/recipe/recipe_pipeline_test.dart` | `flutter test` → 85 pass | `6ef767e` |
| 2026-11-11 | F03-T08 | Benchmark 10.000 step no-op | `tool/benchmark_pipeline.dart` | `dart run tool/benchmark_pipeline.dart` → 39 ms, ~256k step/s | `6ef767e` |
| 2026-11-11 | F04-T01 | Model + parser manifest v1, semver, validasi entrypoint | `lib/core/plugin/plugin_manifest.dart`, `semantic_version.dart` | `flutter test` → 136 pass | `837c8c8` |
| 2026-11-11 | F04-T02 | Pembaca `.berp` aman: zip-slip, symlink, duplikat, limit | `lib/core/plugin/plugin_package.dart` | `flutter test` → 136 pass | `837c8c8` |
| 2026-11-11 | F04-T03 | Verifikator SHA-256 paket/entrypoint | `lib/core/plugin/plugin_integrity.dart` | `flutter test` → 136 pass | `837c8c8` |
| 2026-11-11 | F04-T04 | Model plugin terpasang, status, dan kompatibilitas versi | `lib/core/plugin/installed_plugin.dart` | `flutter test` → 136 pass | `837c8c8` |
| 2026-11-11 | F04-T06 | Service enable/disable/hapus + peringatan core | `lib/core/plugin/plugin_lifecycle.dart` | `flutter test` → 136 pass | `837c8c8` |
| 2026-11-11 | F04-T07 | Model izin/capability + `PermissionGuard` | `lib/core/plugin/plugin_permission.dart` | `flutter test` → 136 pass | `837c8c8` |
| 2026-11-11 | F04-T09 | Registrasi operasi manifest ke registry | `lib/core/plugin/manifest_registrar.dart` | `flutter test` → 136 pass | `837c8c8` |
| 2026-11-11 | F04-T11 | Test adversarial manifest, entrypoint, hash, izin | `test/core/plugin_*_test.dart`, `support/plugin_fixtures.dart` | `flutter test` → 136 pass | `837c8c8` |
| 2026-11-11 | F05-T01 | Kontrak sandbox: config, konteks, izin, cancellation, runtime | `lib/core/runtime/sandbox.dart`, `test/core/sandbox_test.dart` | `flutter test` → 145 pass | `6f0e04a` |
| 2026-11-11 | F06-T01 | SQLite v1, lima tabel, foreign key, migrasi, reopen | `lib/core/storage/app_database.dart`, `test/core/app_database_test.dart` | `flutter test` → 150 pass | `42da04d` |
| 2026-11-11 | F06-T02 | RecipeRepository CRUD, urut update, pencarian literal | `lib/features/recipe/recipe_repository.dart`, test | `flutter test` → 179 pass | `ba03b03` |
| 2026-11-11 | F06-T03 | PluginRepository persist/reload, setEnabled, cascade | `lib/features/plugins/plugin_repository.dart`, test | `flutter test` → 179 pass | `ba03b03` |
| 2026-11-11 | F06-T04 | SettingsRepository tema/sandbox/log opt-in, fallback default | `lib/features/settings/settings_repository.dart`, test | `flutter test` → 179 pass | `ba03b03` |
| 2026-11-11 | F06-T05 | FavoriteRepository add/remove/list/contains | `lib/features/library/favorite_repository.dart`, test | `flutter test` → 179 pass | `ba03b03` |
| 2026-11-11 | F06-T06 | PluginPackageStore filesystem staging + rename atomik | `lib/core/plugin/plugin_package_store.dart`, test | `flutter test` → 179 pass | `ba03b03` |
| 2026-11-11 | F06-T07 | Test storage `sqflite_common_ffi` di seluruh suite | `test/core/app_database_test.dart`, test repository | `flutter test` → 179 pass | `ba03b03` |
| 2026-11-11 | F07-T01 | Token warna/spacing/radius/tipografi + tema light/dark | `lib/core/ui/design_tokens.dart`, `lib/core/ui/app_theme.dart`, `lib/main.dart` | `flutter test` → 184 pass | `7db1759` |
| 2026-11-11 | F07-T02 | Provider tema persisten + provider storage Riverpod | `lib/core/ui/theme_provider.dart`, `lib/core/storage/storage_providers.dart`, `lib/main.dart` | `flutter test` → 188 pass | `5753dc4` |
| 2026-11-11 | F07-T03 | App shell bottom navigation 3 tab + placeholder tab | `lib/core/ui/app_shell.dart`, `lib/main.dart` | `flutter test` → 190 pass | `9d0b432` |

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

### CP-005 — 2026-11-11 — F03 Pipeline Executor (sebagian)

- Status: Sebagian (7/8 task F03). F03-T04 (isolate) blocked sampai host
  runtime/plugin F05 tersedia.
- Perubahan:
  - Tipe engine `PipelineStep`, `PipelineEvent`, `PipelineResult`,
    `CancellationToken`, dan `PipelineErrorPolicy`.
  - `PipelineExecutor` sekuensial: dispatch registry, validasi args, skip
    disabled/unsupported, error terstruktur, timeout per step, pembatalan,
    serta callback/stream progres.
  - Jembatan `Recipe.toPipelineSteps()` dan test end-to-end dummy melalui
    registry; benchmark 10.000 step no-op.
  - Dokumentasi status engine diperbarui di `operations.md` dan
    `ARCHITECTURE.md`.
- File: `lib/core/engine/pipeline.dart`,
  `lib/core/engine/pipeline_executor.dart`,
  `lib/features/recipe/recipe_pipeline.dart`,
  `test/core/pipeline_executor_test.dart`,
  `test/features/recipe/recipe_pipeline_test.dart`,
  `tool/benchmark_pipeline.dart`.
- Verifikasi:
  - `dart format lib test tool` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **85 test lulus**.
  - `dart run tool/benchmark_pipeline.dart` → 10.000 step dalam 39 ms
    (~256.410 step/detik), 20.001 event.
- Catatan/risiko:
  - F03-T04 belum dikerjakan: eksekusi masih di isolate pemanggil dan
    timeout belum bisa mematikan operasi paksa. Host isolate pekerja
    membutuhkan registry/runtime plugin dari F04/F05.
  - F03-T06 sudah menguji timeout in-process; pembersihan isolate dan
    enforcement memori menyusul F03-T04.
  - F03-T07 memakai operasi dummy sesuai izin TODO; integrasi penuh dengan
    plugin loader/runtime diuji ulang setelah F04/F05.
  - D06 tetap terbuka; default stop, mode `continueWithLastOutput` sudah
    tersedia dan diuji.
- Commit: `6ef767e` (kode/test) + commit checkpoint ini.

### CP-006 — 2026-11-11 — F04 Sistem Plugin (sebagian)

- Status: Sebagian (8/11 task F04). T05 sideload, T08 bootstrap core, dan
  T10 service ditunda sampai storage/UI/core.berp tersedia.
- Perubahan:
  - Manifest plugin v1 + parser JSON, validasi ID, semver, tier, entrypoint,
    izin, operations, dan integrity.
  - Pembaca `.berp` dengan batas ukuran/entri, deteksi zip-slip, symlink, dan
    duplikat; verifikasi SHA-256.
  - Model plugin terpasang + status kompatibilitas; registrasi descriptor
    manifest; siklus enable/disable/hapus; guard izin.
  - Test adversarial untuk manifest palsu, entrypoint hilang, hash salah,
    izin tak dikenal, dan paket berbahaya.
  - Contoh manifest di `PLUGINS.md` diselaraskan dengan kontrak parameter
    (`boolean` + label) dan batas paket didokumentasikan.
- File: `lib/core/plugin/plugin_*.dart`,
  `lib/core/plugin/semantic_version.dart`, test plugin core, `PLUGINS.md`,
  `ARCHITECTURE.md`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **136 test lulus**.
- Catatan/risiko:
  - Batas ukuran mencegah zip bomb berdasarkan metadata dan hasil dekompresi;
    library `archive` tetap mendekompresi sebelum ukuran aktual diketahui.
  - `PermissionGuard` baru menyediakan hook; enforcement di runtime Lua/WASM
    menunggu F05.
  - Belum ada ekstraksi atomik/filesystem dan persistensi; menunggu F06.
- Commit: `837c8c8` (kode/test) + commit checkpoint ini.

### CP-007 — 2026-11-11 — F05-T01 Kontrak Sandbox

- Status: Selesai (1/9 task F05).
- Perubahan:
  - `SandboxConfig` immutable dengan default timeout 2 detik, memori 64 MiB,
    dan izin `cpu`; override tervalidasi.
  - `SandboxContext` membawa identitas plugin/operasi/step, izin aktif, dan
    token pembatalan; menyediakan `requirePermission()` dan
    `ensureActive()`.
  - Antarmuka `SandboxRuntime` untuk runtime DSL/Lua/WASM.
  - Dokumentasi kontrak ditambahkan ke `ARCHITECTURE.md` dan
    `operations.md`.
- File: `lib/core/runtime/sandbox.dart`, `test/core/sandbox_test.dart`,
  `ARCHITECTURE.md`, `operations.md`.
- Verifikasi:
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **145 test lulus**.
- Catatan/risiko: timeout/memori baru berupa konfigurasi; enforcement dan
  pembersihan isolate menunggu F05-T04. F05-T02 menunggu D08 dan F05-T03
  menunggu D02.
- Commit: `6f0e04a` (kode/test) + commit checkpoint ini.

### CP-008 — 2026-11-11 — F06-T01 SQLite + Migrasi v1

- Status: Selesai (1/7 task F06).
- Perubahan:
  - `AppDatabase` membuka SQLite dengan schema v1, `PRAGMA foreign_keys`,
    dan migrasi berantai.
  - Tabel `recipe`, `plugin`, `setting`, `favorite`, dan `plugin_permission`;
    permission memakai foreign key cascade ke plugin.
  - Factory/path dapat diinjeksi untuk test `sqflite_common_ffi`.
  - Test mencakup create, reopen/persistensi, cascade, migrasi v0→v1, dan
    migrasi yang belum tersedia.
- File: `lib/core/storage/app_database.dart`,
  `test/core/app_database_test.dart`, `ARCHITECTURE.md`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **150 test lulus**.
- Catatan/risiko: repository CRUD dan filesystem paket plugin belum ada
  (F06-T02–T06). Schema dapat berubah lewat migrasi berikutnya.
- Commit: `42da04d` (kode/test) + commit checkpoint ini.

### CP-009 — 2026-11-11 — F06 Storage Selesai

- Status: Selesai (7/7 task F06).
- Perubahan:
  - `RecipeRepository`: CRUD, urut update terakhir, pencarian nama literal
    case-insensitive, validasi sebelum simpan, error data rusak terstruktur.
  - `PluginRepository`: persist metadata terpasang, setEnabled, update tanpa
    menghapus izin, cascade saat delete.
  - `SettingsRepository`: tema, batas sandbox, log opt-in; default aman dan
    fallback per-key untuk nilai rusak.
  - `FavoriteRepository`: add/remove/list/contains, idempoten, urut terbaru.
  - `PluginPackageStore`: ekstraksi `.berp` ke staging lalu rename atomik ke
    `<root>/<pluginId>/<version>`; staging dibersihkan saat gagal dan saat
    uninstall.
  - Semua storage test berjalan dengan `sqflite_common_ffi` tanpa device.
- File: `lib/core/storage/app_database.dart`,
  `lib/core/plugin/plugin_package_store.dart`,
  `lib/features/recipe/recipe_repository.dart`,
  `lib/features/plugins/plugin_repository.dart`,
  `lib/features/settings/settings_repository.dart`,
  `lib/features/library/favorite_repository.dart`, test terkait,
  `ARCHITECTURE.md`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **179 test lulus**.
- Catatan/risiko:
  - Rename atomik menghapus target lama lebih dulu; ada jeda singkat tanpa
    versi aktif. Aman karena metadata "terpasang" hanya ditulis setelah
    ekstraksi sukses.
  - Grant izin per plugin belum diisi otomatis; dialog izin UI F07/F11 yang
    akan menulis tabel `plugin_permission`.
  - F05-T02/T03 masih blocked (D08/D02); lanjut ke F07.
- Commit: `42da04d` + `ba03b03` (kode/test) + commit checkpoint ini.

### CP-010 — 2026-11-11 — F07-T01 Token Desain & Tema

- Status: Selesai (1/10 task F07).
- Perubahan:
  - `AppPalette` light/dark sesuai `DESIGN.md` §2 + konversi `ColorScheme`.
  - Skala `AppSpacing`, `AppRadius`, dan target sentuh 44dp.
  - `AppTheme` light/dark: tipografi (display/h1/h2/body/caption), border
    tipis, tombol, input, snackbar, bottom navigation.
  - `main.dart` memakai `AppTheme` menggantikan `ColorScheme.fromSeed`.
- File: `lib/core/ui/design_tokens.dart`, `lib/core/ui/app_theme.dart`,
  `lib/main.dart`, `test/core/ui/app_theme_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **184 test lulus**.
- Catatan/risiko: font Inter belum dibundel; fallback ke font sistem (D04).
- Commit: `7db1759` (kode/test) + commit checkpoint ini.

### CP-011 — 2026-11-11 — F07-T02 Provider Tema Persisten

- Status: Selesai (2/10 task F07).
- Perubahan:
  - `appDatabaseProvider` dan `settingsRepositoryProvider` Riverpod.
  - `themeModeProvider` (`AsyncNotifier`) memuat tema dari SQLite dan
    menyimpannya kembali tanpa mengubah setting lain.
  - `themeModeFor()` memetakan `AppThemeMode` ke `ThemeMode` Flutter.
  - `main.dart` memilih tema dari provider.
- File: `lib/core/storage/storage_providers.dart`,
  `lib/core/ui/theme_provider.dart`, `lib/main.dart`,
  `test/core/ui/theme_provider_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **188 test lulus**.
- Catatan/risiko: saat state masih loading, aplikasi memakai `system` sebagai
  fallback.
- Commit: `5753dc4` (kode/test) + commit checkpoint ini.

### CP-012 — 2026-11-11 — F07-T03 App Shell

- Status: Selesai (3/10 task F07).
- Perubahan:
  - `AppShell` dengan `BottomNavigationBar` 3 tab: Home, Library, Settings.
  - `IndexedStack` menjaga state tiap tab saat berpindah.
  - Placeholder Home/Library/Settings untuk diisi F08/F10/F12.
  - `main.dart` memakai `AppShell` sebagai home.
- File: `lib/core/ui/app_shell.dart`, `lib/main.dart`,
  `test/core/ui/app_shell_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **190 test lulus**.
- Catatan/risiko: tiga tab masih placeholder; konten menyusul per fitur.
- Commit: `9d0b432` (kode/test) + commit checkpoint ini.

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
| 2026-11-11 | D08, F05-T02 | Skema DSL final belum ditetapkan | Menunda implementasi runtime DSL | Terbuka |
| 2026-11-11 | F00-T06 | `operations.md` belum ada | Kontrak Operation belum tertulis | Selesai (F00-T06) |
| 2026-11-11 | D06, F03-T03 | Kebijakan stop vs lanjut saat error step | Memengaruhi UI dan test engine | Terbuka (default stop; mode lanjut tersedia) |
| 2026-11-11 | F03-T04, F03-T06 | Host isolate membutuhkan registry/runtime plugin dari F05 | Isolate offload, kill saat timeout, dan enforcement memori belum aktif | Terbuka |
| 2026-11-11 | F04-T05, F04-T10 | Sideload dan service manager membutuhkan UI F07/F11 | Storage/filesystem siap; alur instalasi end-to-end belum tersedia | Terbuka |
| 2026-11-11 | F04-T08 | Bootstrap `core.berp` membutuhkan aset dan runtime F13/F05 | First-run belum bisa memasang operasi core | Terbuka |
| 2026-11-11 | D07 | Target rilis MVP belum ditetapkan | Prioritas task belum berbatas waktu | Terbuka |

## 9. Catatan Keputusan (diisi saat ada)

| Tanggal | ID | Keputusan | Alasan | Dampak |
|---|---|---|---|---|
| — | — | — | — | — |
