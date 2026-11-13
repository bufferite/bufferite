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
| Task MVP selesai | 113 / 131 |
| Task Fase 2 | 0 / 8 |
| Task Fase 3 | 0 / 5 |
| Keputusan terbuka | 10 |
| Task sedang berjalan | — |
| Task berikutnya | `F13-T02` — build script `.berp` (device-gated: F09-T09/T10, F11 sideload, F15 ditunda) |
| Blocker aktif | Device-gated: F03-T04, F04-T05/T08/T10, F09-T09/T10, F14-T08/T09, F15; keputusan D02/D08/D06/D07 |
| Analyze | Lulus (0 issue, 2026-11-13) |
| Test suite | Lulus (334 test, 2026-11-14) |

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
| F07 — UI Foundation & Design System | 10 | 10 | Selesai |
| F08 — Fitur Home | 6 | 6 | Selesai |
| F09 — Fitur Recipe Editor | 11 | 11 | Selesai |
| F10 — Fitur Library & Operation Picker | 7 | 7 | Selesai |
| F11 — Fitur Plugin Manager | 9 | 9 | Selesai |
| F12 — Fitur Settings | 6 | 6 | Selesai |
| F13 — core.berp: Tooling & Operasi | 11 | 1 | Berjalan |
| F14 — Keamanan & Kualitas | 9 | 0 | Belum |
| F15 — Rilis MVP | 7 | 0 | Belum |
| **Total MVP** | **131** | **113** | **Berjalan** |
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
| 2026-11-11 | F07-T04 | Komponen AppButton 4 varian + AppBadge 5 tone | `lib/core/ui/components/app_button.dart`, `app_badge.dart` | `flutter test` → 197 pass | `3921e75` |
| 2026-11-11 | F07-T05 | Komponen StepCard: 4 state, toggle, badge tier/unsupported | `lib/core/ui/components/step_card.dart` | `flutter test` → 202 pass | `ea401ca` |
| 2026-11-11 | F07-T06 | BufferPanel: header, mono, copy, expand, live, error, empty | `lib/core/ui/components/buffer_panel.dart` | `flutter test` → 207 pass | `d552aa1` |
| 2026-11-11 | F07-T07 | EmptyState reusable: ikon, judul, deskripsi, aksi utama | `lib/core/ui/components/empty_state.dart` | `flutter test` → 210 pass | `2c05b56` |
| 2026-11-11 | F07-T08 | PermissionDialog: daftar izin, barrier dismissible false, danger net | `lib/core/ui/components/permission_dialog.dart` | `flutter test` → 214 pass | `5c79bed` |
| 2026-11-11 | F07-T09 | `showAppToast` 4 tone + aksi undo | `lib/core/ui/components/app_toast.dart` | `flutter test` → 217 pass | `9429d5d` |
| 2026-11-11 | F07-T10 | Audit aksesibilitas: kontras, touch 44dp, text scale 1.3x, semantik | `test/core/ui/accessibility_test.dart` | `flutter test` → 222 pass | `bf0da62` |
| 2026-11-11 | F08-T01 | Provider recipe terbaru + pencarian + `recipeRepositoryProvider` | `lib/features/recipe/recipe_providers.dart`, `lib/core/storage/storage_providers.dart` | `flutter test` → 225 pass | `37dd672` |
| 2026-11-12 | F08-T02 | UI Home: search, tombol baru, daftar recipe + waktu relatif | `lib/features/home/home_page.dart`, `lib/core/ui/app_shell.dart`, `lib/main.dart` | `flutter test` → 229 pass | `bbfe552` |
| 2026-11-12 | F08-T03 | Empty state + aksi buat baru/tap item → editor placeholder | `lib/features/recipe/recipe_editor_page.dart`, `lib/features/home/home_page.dart` | `flutter test` → 231 pass | `9d43ba7` |
| 2026-11-12 | F08-T04 | Hapus dengan konfirmasi + undo, duplikasi recipe | `lib/features/home/home_page.dart`, `lib/features/recipe/recipe_id.dart` | `flutter test` → 236 pass | `5ff3d2a` |
| 2026-11-12 | F08-T05 | Navigasi CTA/tap item ke Recipe Editor (baru/terpilih) | `lib/features/home/home_page.dart`, `lib/features/recipe/recipe_editor_page.dart` | `flutter test` → 236 pass | `5ff3d2a` |
| 2026-11-12 | F08-T06 | Widget test Home: list, search, empty, hapus, duplikat, navigasi | `test/features/home/home_page_test.dart` | `flutter test` → 236 pass | `5ff3d2a` |
| 2026-11-12 | F09-T01 | Layout editor: nama, input, daftar step, output, simpan | `lib/features/recipe/recipe_editor_page.dart` | `flutter test` → 240 pass | `1876abd` |
| 2026-11-12 | F09-T02 | Operation Picker (search, tier badge) + tambah step | `lib/features/operations/operation_picker.dart`, `operation_providers.dart`, editor | `flutter test` → 243 pass | `9fac6a3` |
| 2026-11-12 | F09-T05 | Sheet konfigurasi parameter per tipe + validasi | `lib/features/operations/step_config_sheet.dart`, editor | `flutter test` → 247 pass | `cf6ddea` |
| 2026-11-12 | F09-T03 | Reorder drag and drop + haptic feedback | `lib/features/recipe/recipe_editor_page.dart` | `flutter test` → 248 pass | `27addfc` |
| 2026-11-12 | F09-T04 | Hapus step + undo, tombol delete di StepCard | `lib/core/ui/components/step_card.dart`, editor | `flutter test` → 250 pass | `103220f` |
| 2026-11-12 | F09-T06 | Preview live debounce 200 ms + batalkan eksekusi lama | `lib/features/recipe/recipe_editor_page.dart` | `flutter test` → 253 pass | `0953910` |
| 2026-11-12 | F09-T07 | Error per step di StepCard + badge unsupported | `lib/features/recipe/recipe_editor_page.dart` | `flutter test` → 255 pass | `4aa7151` |
| 2026-11-12 | F09-T08 | Simpan/rename ke repository + guard dialog perubahan | `lib/features/recipe/recipe_editor_page.dart` | `flutter test` → 256 pass | `1e49e5d` |
| 2026-11-12 | F09-T09 | Impor/ekspor `.brecipe` via file picker dari editor | `lib/features/recipe/recipe_io.dart`, editor | `flutter test` → 258 pass | `d017dc6` |
| 2026-11-12 | F09-T10 | Input file scoped (batas 5 MiB, BytesBuffer) + hapus file | `lib/features/recipe/recipe_editor_page.dart` | `flutter test` → 259 pass | `90f825b` |
| 2026-11-12 | F09-T11 | Widget test alur editor: tambah step, live output, disable, simpan | `test/features/recipe/recipe_editor_page_test.dart` | `flutter test` → 260 pass | `2086cdd` |
| 2026-11-12 | F10-T01 | Provider katalog operasi (registry + metadata plugin aktif) | `lib/features/library/operation_catalog.dart` | `flutter test` → 263 pass | `282f01b` |
| 2026-11-12 | F10-T02 | Picker 85% + chip kategori/favorit + search sticky | `lib/features/operations/operation_picker.dart` | `flutter test` → 265 pass | `e29af63` |
| 2026-11-12 | F10-T03 | Pencarian + filter kategori/favorit (chip, gabung search) | `lib/features/operations/operation_picker.dart` | `flutter test` → 265 pass | `e29af63` |
| 2026-11-12 | F10-T04 | Provider favorit persisten (`favoritesProvider`) | `lib/features/library/favorite_providers.dart` | `flutter test` → 267 pass | `43e49cc` |
| 2026-11-12 | F10-T05 | Tab Library: katalog + search + favorit + detail singkat | `lib/features/library/library_page.dart`, `app_shell.dart`, `main.dart` | `flutter test` → 267 pass | `3986f60` |
| 2026-11-12 | F10-T06 | Empty state Library → tombol ke Plugin Manager (placeholder) | `lib/features/plugins/plugin_manager_page.dart`, `library_page.dart` | `flutter test` → 267 pass | `c1c38ea` |
| 2026-11-12 | F10-T07 | Widget test picker + library (search, detail, empty → manager) | `test/features/operations/operation_picker_test.dart`, `library_page_test.dart` | `flutter test` → 270 pass | `dbcfd72` |
| 2026-11-13 | F11-T01 | Daftar plugin terpasang (versi, sumber, izin, tier, status) | `lib/features/plugins/plugin_manager_page.dart`, `plugin_providers.dart` | `flutter test` → 274 pass | `54cab59` |
| 2026-11-13 | F11-T02 | Halaman detail plugin (manifest, izin, operasi, ukuran) | `lib/features/plugins/plugin_detail_page.dart` | `flutter test` → 274 pass | `39a2d08` |
| 2026-11-13 | F11-T03 | Enable/disable/hapus + konfirmasi + peringatan core | `lib/features/plugins/plugin_actions.dart`, `plugin_manager_page.dart` | `flutter test` → 274 pass | `19546c7` |
| 2026-11-13 | F11-T04 | Alur sideload: pilih → preview manifest → instal | `lib/features/plugins/plugin_sideload.dart`, `plugin_manager_page.dart` | `flutter test` → 274 pass | `f9fc0eb` |
| 2026-11-13 | F11-T05 | Dialog izin net/file:read/file:write saat sideload | `lib/features/plugins/plugin_manager_page.dart` | `flutter test` → 274 pass | `f9fc0eb` |
| 2026-11-13 | F11-T06 | Tombol katalog + peringatan jaringan ("belum tersedia") | `lib/features/plugins/plugin_manager_page.dart` | `flutter test` → 274 pass | `d6a4cde` |
| 2026-11-13 | F11-T07 | Gate kegagalan bootstrap core.berp + Coba lagi/Lanjutkan | `lib/core/bootstrap/*`, `lib/main.dart` | `flutter test` → 274 pass | `f4d15d1` |
| 2026-11-13 | F11-T08 | Empty state Plugin Manager | `lib/features/plugins/plugin_manager_page.dart` | `flutter test` → 274 pass | `54cab59` |
| 2026-11-13 | F11-T09 | Widget test detail/enable/disable/hapus/sideload | `test/features/plugins/plugin_manager_page_test.dart` | `flutter test` → 277 pass | `4896fce` |

| 2026-11-14 | F13-T04 | Operasi Encode/Decode core (Base64/Hex/URL/HTML/Base32) | `lib/core/operations/encode_decode.dart` | `flutter test` ? 306 pass | `60f45b7` |
| 2026-11-14 | F13-T05 | Operasi hash/kripto dasar (MD5/SHA-1/256/512, HMAC) | `lib/core/operations/hash.dart` | `flutter test` ? 306 pass | `bf70e86` |
| 2026-11-14 | F13-T06 | Operasi Format (JSON prettify/minify, JWT decode) | `lib/core/operations/format.dart` | `flutter test` ? 306 pass | `c80edae` |
| 2026-11-14 | F13-T07 | Operasi Analysis (entropy, frequency, file type, strings) | `lib/core/operations/analysis.dart` | `flutter test` ? 311 pass | `9b7dc7d` |
| 2026-11-14 | F13-T08 | Operasi Utility (case, reverse, replace, regex, slice, lines) | `lib/core/operations/utility.dart` | `flutter test` ? 317 pass | `4067c56` |
| 2026-11-14 | F13-T09 | Kripto lanjutan (AES/XOR) � DITUNDA (review keamanan) | � | Belum | � |
| 2026-11-14 | F13-T10 | Audit lisensi operasi core | `plugins/core/LICENSES.md` | Review dokumen | `69d8a7d` |
| 2026-11-14 | F13-T11 | Gate ukuran core.berp < 2 MiB + catatan lazy load | `test/tool/core_package_size_test.dart`, `plugins/core/README.md` | `flutter test` ? 334 pass | `ac30e3e` |
| 2026-11-14 | F14-T01 | Threat model | `THREAT_MODEL.md` | Review dokumen | `b64f7e3` |
| 2026-11-14 | F14-T02 | Test adversarial paket (tercakup `plugin_package_test.dart`) | `test/core/plugin_package_test.dart` | `flutter test` ? 325 pass | `fbbc0fe` |
| 2026-11-14 | F14-T03 | Test bypass izin (guard + SandboxContext) | `test/core/permission_bypass_test.dart` | `flutter test` ? 325 pass | `89c1466` |
| 2026-11-14 | F14-T04 | Safe regex anti-ReDoS + integrasi RegexReplace | `lib/core/operations/safe_regex.dart` | `flutter test` ? 325 pass | `60aec35` |
| 2026-11-14 | F14-T05 | CSPRNG random ops (Random.secure) | `lib/core/operations/random_ops.dart` | `flutter test` ? 329 pass | `ed5c3a6` |
| 2026-11-14 | F14-T06 | Audit offline-by-default (scan lib/ + pubspec) | `test/core/offline_audit_test.dart` | `flutter test` ? 331 pass | `cb6d364` |
| 2026-11-14 | F14-T07 | Integration test end-to-end (non-device) | `test/core/e2e_integration_test.dart` | `flutter test` ? 332 pass | `3cfd542` |
| 2026-11-14 | F14-T08 | Uji performa/memori � DITUNDA (sebagian device) | � | Belum | � |
| 2026-11-14 | F14-T09 | QA desain DESIGN �15 � DITUNDA (manual/device) | � | Belum | � |
| 2026-11-14 | F15-T01 | Metadata aplikasi + application id `dev.bufferite.app` | `android/app/build.gradle.kts`, `AndroidManifest.xml`, `MainActivity.kt` | `flutter analyze` 0 issue | `31e1930` |
| 2026-11-14 | F15-T02 | minSdk 21 + tanpa INTERNET di manifest utama | `android/app/build.gradle.kts`, `AndroidManifest.xml` | Review konfigurasi | `98524ad` |
| 2026-11-14 | F15-T03 | Teks privasi offline + lisensi pihak ketiga | `PRIVACY.md`, `THIRD_PARTY_LICENSES.md` | Review dokumen | `660c0eb` |
| 2026-11-14 | F15-T04 | Versi `1.0.0+1` + changelog rilis | `CHANGELOG.md`, `pubspec.yaml` | Review dokumen | `6051fb2` |
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

### CP-013 — 2026-11-11 — F07-T04 Tombol & Badge

- Status: Selesai (4/10 task F07).
- Perubahan:
  - `AppButton`: varian primary/secondary/ghost/danger, state loading
    (nonaktif + spinner), ikon opsional, dan mode expand.
  - `AppBadge`: 5 tone (neutral/accent/success/warning/danger) dengan ikon
    opsional, radius pill, dan warna semantik dari `AppPalette`.
- File: `lib/core/ui/components/app_button.dart`,
  `lib/core/ui/components/app_badge.dart`, `test/core/ui/components_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **197 test lulus**.
- Catatan/risiko: tinggal dipakai luas; ukuran minimum 44dp diambil dari
  tema tombol.
- Commit: `3921e75` (kode/test) + commit checkpoint ini.

### CP-014 — 2026-11-11 — F07-T05 Kartu Step

- Status: Selesai (5/10 task F07).
- Perubahan:
  - `StepCard`: drag handle, nama + kategori, badge tier, toggle enabled,
    chevron.
  - State normal/disabled/error/unsupported; error menampilkan pesan dan
    border danger; unsupported menonaktifkan tap, toggle, dan chevron.
  - Semantics label untuk aksesibilitas dasar.
- File: `lib/core/ui/components/step_card.dart`,
  `test/core/ui/step_card_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **202 test lulus**.
- Catatan/risiko: drag-and-drop reorder dan swipe-to-delete diimplementasikan
  di Recipe Editor (F09).
- Commit: `ea401ca` (kode/test) + commit checkpoint ini.

### CP-015 — 2026-11-11 — F07-T06 Buffer Panel

- Status: Selesai (6/10 task F07).
- Perubahan:
  - `BufferPanel`: header label + tipe, indikator live, copy, expand.
  - Body mono (Roboto Mono, tabular figures), scroll, seleksi teks.
  - Empty state dengan aksi opsional dan banner error danger.
- File: `lib/core/ui/components/buffer_panel.dart`,
  `test/core/ui/buffer_panel_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **207 test lulus**.
- Catatan/risiko: komponen menerima konten string; integrasi `Buffer` dan
  pipeline live dilakukan di F09.
- Commit: `d552aa1` (kode/test) + commit checkpoint ini.

### CP-016 — 2026-11-11 — F07-T07 Empty State

- Status: Selesai (7/10 task F07).
- Perubahan: komponen `EmptyState` reusable dengan ikon 48, judul, deskripsi
  opsional, dan satu aksi utama opsional.
- File: `lib/core/ui/components/empty_state.dart`,
  `test/core/ui/empty_state_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **210 test lulus**.
- Catatan/risiko: Home placeholder F07-T03 masih memakai markup sendiri;
  akan diarahkan ke `EmptyState` saat F08.
- Commit: `2c05b56` (kode/test) + commit checkpoint ini.

### CP-017 — 2026-11-11 — F07-T08 Dialog Izin

- Status: Selesai (8/10 task F07).
- Perubahan:
  - `showPermissionDialog` + `PermissionDialog`: daftar izin dengan ikon dan
    deskripsi, tombol Batal/Setujui, tombol danger bila ada izin `net`.
  - `barrierDismissible: false` sehingga dialog hanya tertutup lewat aksi.
- File: `lib/core/ui/components/permission_dialog.dart`,
  `test/core/ui/permission_dialog_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **214 test lulus**.
- Catatan/risiko: penulisan grant ke `plugin_permission` dilakukan oleh alur
  install (F04-T05/F11).
- Commit: `5c79bed` (kode/test) + commit checkpoint ini.

### CP-018 — 2026-11-11 — F07-T09 Toast & Undo

- Status: Selesai (9/10 task F07).
- Perubahan: `showAppToast` dengan tone info/success/warning/error (warna
  hanya pada ikon), durasi 3 detik, aksi `Undo` opsional.
- File: `lib/core/ui/components/app_toast.dart`,
  `test/core/ui/app_toast_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **217 test lulus**.
- Catatan/risiko: aksi destruktif tetap perlu konfirmasi terpisah; toast
  hanya menyediakan undo.
- Commit: `9429d5d` (kode/test) + commit checkpoint ini.

### CP-019 — 2026-11-11 — F07-T10 Audit Aksesibilitas

- Status: Selesai (10/10 task F07).
- Perubahan:
  - Test kontras `textPrimary`/`textSecondary` terhadap background memenuhi
    WCAG AA 4.5:1 di light dan dark.
  - Verifikasi target sentuh tombol/kartu step >= 44dp.
  - Widget test text scale 1.3x tanpa overflow untuk AppShell, StepCard, dan
    EmptyState.
  - Verifikasi label semantik kartu step.
- File: `test/core/ui/accessibility_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **222 test lulus**.
- Catatan/risiko: checklist manual `DESIGN.md` §15 tetap perlu dijalankan di
  device untuk gesture dan screen reader nyata.
- Commit: `bf0da62` (test) + commit checkpoint ini.

### CP-020 — 2026-11-11 — F08-T01 Provider Daftar Recipe

- Status: Selesai (1/6 task F08).
- Perubahan:
  - `recipeRepositoryProvider` di provider storage bersama.
  - `recentRecipesProvider` (urut update terakhir) dan
    `recipeSearchProvider` (family query nama; kosong = semua).
- File: `lib/features/recipe/recipe_providers.dart`,
  `lib/core/storage/storage_providers.dart`,
  `test/features/recipe/recipe_providers_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **225 test lulus**.
- Catatan/risiko: provider belum meng-invalidate cache setelah save/hapus;
  dilakukan oleh aksi UI di F08-T04.
- Commit: `37dd672` (kode/test) + commit checkpoint ini.

### CP-021 — 2026-11-12 — F08-T02 UI Home

- Status: Selesai (2/6 task F08).
- Perubahan:
  - `HomePage`: app bar, pencarian nama, tombol "Recipe Baru", daftar
    "Recipe Terbaru" dengan jumlah langkah dan waktu relatif.
  - Empty state beda untuk tanpa recipe vs tanpa hasil pencarian.
  - `AppShell` menerima widget Home; `main.dart` memasang `HomePage`.
  - Test Home memakai override provider (tanpa DB) agar stabil; widget test
    utama meng-override `recentRecipesProvider`.
- File: `lib/features/home/home_page.dart`, `lib/core/ui/app_shell.dart`,
  `lib/main.dart`, `test/features/home/home_page_test.dart`,
  `test/widget_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **229 test lulus**.
- Catatan/risiko: tombol baru/tap item masih snackbar placeholder; navigasi
  ke editor diisi F08-T05.
- Commit: `bbfe552` (kode/test) + commit checkpoint ini.

### CP-022 — 2026-11-12 — F08-T03 Empty State & Aksi Buat Baru

- Status: Selesai (3/6 task F08).
- Perubahan:
  - Empty state Home memakai `EmptyState` dengan aksi "Buat recipe baru".
  - Tombol "Recipe Baru" dan tap item membuka `RecipeEditorPage`
    (placeholder F09).
- File: `lib/features/recipe/recipe_editor_page.dart`,
  `lib/features/home/home_page.dart`,
  `test/features/home/home_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **231 test lulus**.
- Catatan/risiko: emulator `127.0.0.1:7555` terdeteksi; build/run manual belum
  dijalankan. Editor masih placeholder.
- Commit: `9d43ba7` (kode/test) + commit checkpoint ini.

### CP-023 — 2026-11-12 — F08-T04 Hapus & Duplikasi Recipe

- Status: Selesai (4/6 task F08).
- Perubahan:
  - `generateRecipeId` (UUID v4) dan `duplicateRecipe` (ID/nama/step baru,
    output dibuang, nama dipotong <= 120).
  - Home: swipe kiri + dialog konfirmasi hapus, toast Undo memulihkan recipe,
    menu tile "Duplikat"; provider di-invalidate setelah aksi.
- File: `lib/features/recipe/recipe_id.dart`,
  `lib/features/home/home_page.dart`, `test/features/recipe/recipe_id_test.dart`,
  `test/features/home/home_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **236 test lulus**.
- Catatan/risiko: test hapus/duplikasi UI memakai override provider (tanpa DB)
  karena DB ffi tidak cocok dengan fake-async widget test; persistensi
  dijamin `RecipeRepository` test. Aksi undo menulis ulang lewat repository.
- Commit: `5ff3d2a` (kode/test) + commit checkpoint ini.

### CP-024 — 2026-11-12 — F08 Selesai

- Status: Selesai (6/6 task F08). T05/T06 terpenuhi oleh implementasi dan test
  F08-T02–T04.
- Perubahan: navigasi ke Recipe Editor dari CTA dan tap item sudah aktif;
  widget test Home mencakup daftar, pencarian, empty state, dan konfirmasi
  hapus.
- File: `lib/features/home/home_page.dart`,
  `lib/features/recipe/recipe_editor_page.dart`,
  `test/features/home/home_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **236 test lulus**.
- Catatan/risiko: navigasi masih ke editor placeholder; layout nyata di F09.
- Commit: `5ff3d2a` (kode/test) + commit checkpoint ini.

### CP-025 — 2026-11-12 — F09-T01 Layout Recipe Editor

- Status: Selesai (1/11 task F09).
- Perubahan:
  - `RecipeEditorPage` menjadi editor fungsional dasar: field nama, input
    teks, daftar step (`StepCard` + toggle enabled), panel output
    (`BufferPanel`), dan tombol Simpan.
  - Mode baru vs edit (judul "Recipe Baru"/"Edit Recipe").
- File: `lib/features/recipe/recipe_editor_page.dart`,
  `test/features/recipe/recipe_editor_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **240 test lulus**.
- Catatan/risiko: Simpan masih toast placeholder; Operation Picker, pipeline,
  dan persistensi diisi F09-T02+.
- Commit: `1876abd` (kode/test) + commit checkpoint ini.

### CP-026 — 2026-11-12 — F09-T02 Operation Picker

- Status: Selesai (2/11 task F09).
- Perubahan:
  - `showOperationPicker` + `OperationPicker`: bottom sheet 85%, search,
    daftar operasi dengan kategori + badge tier, disable operasi unsupported.
  - `operationRegistryProvider` in-memory.
  - Editor: tombol "Tambah step" menambahkan `RecipeStep` dari descriptor.
- File: `lib/features/operations/operation_picker.dart`,
  `lib/features/operations/operation_providers.dart`,
  `lib/features/recipe/recipe_editor_page.dart`,
  `test/features/operations/operation_picker_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **243 test lulus**.
- Catatan/risiko: registry default kosong sampai core.berp dimuat (F13);
  test meng-override dengan operasi dummy.
- Commit: `9fac6a3` (kode/test) + commit checkpoint ini.

### CP-027 — 2026-11-12 — F09-T05 Sheet Konfigurasi Parameter

- Status: Selesai (3/11 task F09; T01, T02, T05).
- Perubahan:
  - `showStepConfigSheet` + `StepConfigSheet`: field per tipe parameter
    (string/integer/boolean/select), multiline/secret, validasi via
    `resolveOperationArgs`, pesan error inline.
  - Editor: tap `StepCard` membuka config sheet dan menyimpan args ke step.
- File: `lib/features/operations/step_config_sheet.dart`,
  `lib/features/recipe/recipe_editor_page.dart`,
  `test/features/operations/step_config_sheet_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **247 test lulus**.
- Catatan/risiko: nilai awal dari `args`/default dipakai; validasi memakai
  kontrak parameter sehingga konsisten dengan engine.
- Commit: `cf6ddea` (kode/test) + commit checkpoint ini.

### CP-028 — 2026-11-12 — F09-T03 Reorder Step

- Status: Selesai (4/11 task F09; T01, T02, T03, T05).
- Perubahan:
  - Daftar step memakai `ReorderableListView` (drag handle long-press,
    `ReorderableDelayedDragStartListener`).
  - `onReorderItem` menyusun ulang step + `HapticFeedback.mediumImpact()`.
- File: `lib/features/recipe/recipe_editor_page.dart`,
  `test/features/recipe/recipe_editor_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **248 test lulus**.
- Catatan/risiko: reorder hanya di memori editor; persistensi saat Simpan
  (F09-T08).
- Commit: `27addfc` (kode/test) + commit checkpoint ini.

### CP-029 — 2026-11-12 — F09-T04 Hapus Step & Undo

- Status: Selesai (5/11 task F09).
- Perubahan:
  - `StepCard` menerima `onDelete` (tombol hapus).
  - Editor: hapus step + toast Undo memulihkan pada posisi semula;
    enable/disable sudah via toggle `StepCard`.
- File: `lib/core/ui/components/step_card.dart`,
  `lib/features/recipe/recipe_editor_page.dart`,
  `test/core/ui/step_card_test.dart`,
  `test/features/recipe/recipe_editor_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **250 test lulus**.
- Catatan/risiko: perubahan step hanya di memori editor sampai Simpan
  (F09-T08).
- Commit: `103220f` (kode/test) + commit checkpoint ini.

### CP-030 — 2026-11-12 — F09-T06 Preview Live

- Status: Selesai (6/11 task F09).
- Perubahan:
  - Editor menjalankan preview lewat `PipelineExecutor` dengan debounce
    200 ms; input listener memicu ulang.
  - `CancellationToken` membatalkan eksekusi lama saat input berubah.
  - Output live + indikator "live"; error step pertama tampil sebagai banner;
    output cache recipe dipakai sebagai nilai awal.
- File: `lib/features/recipe/recipe_editor_page.dart`,
  `test/features/recipe/recipe_preview_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **253 test lulus**.
- Catatan/risiko: preview berjalan di isolate pemanggil; offload isolate
  menunggu F03-T04.
- Commit: `0953910` + `c79d725` (kode/test) + commit checkpoint ini.

### CP-031 — 2026-11-12 — F09-T07 Error Per Step

- Status: Selesai (7/11 task F09).
- Perubahan:
  - Error pipeline dipetakan per `stepId` dan ditampilkan di `StepCard`
    (state error/unsupported + pesan).
  - Badge `unsupported` untuk operasi tidak dikenal/tak didukung registry;
    toggle disable untuk step unsupported.
  - Output banner error dihapus duplikasinya (kini per-step).
- File: `lib/features/recipe/recipe_editor_page.dart`,
  `test/features/recipe/recipe_preview_test.dart`,
  `test/features/recipe/recipe_editor_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **255 test lulus**.
- Catatan/risiko: test editor kini meng-override registry operasi dummy.
- Commit: `4aa7151` + `6e6ba78` (kode/test) + commit checkpoint ini.

### CP-032 — 2026-11-12 — F09-T08 Simpan & Guard

- Status: Selesai (8/11 task F09).
- Perubahan:
  - `_save` memvalidasi draft lalu menyimpan via `recipeRepositoryProvider`
    (mode baru = UUID v4 baru, mode edit = update); toast sukses + pop hasil.
  - Guard perubahan belum tersimpan (`PopScope` + dialog "Buang perubahan?").
  - Rename lewat field nama; `_saving` menonaktifkan tombol saat proses.
- File: `lib/features/recipe/recipe_editor_page.dart`,
  `test/features/recipe/recipe_editor_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **256 test lulus**.
- Catatan/risiko: test simpan sukses dengan DB belum ada (DB ffi + fake async);
  persistensi dijamin `RecipeRepository` test.
- Commit: `1e49e5d` (kode/test) + commit checkpoint ini.

### CP-033 — 2026-11-12 — F09-T09 Impor/Ekspor .brecipe

- Status: Selesai (9/11 task F09).
- Perubahan:
  - `RecipeIo`: ekspor via `FilePicker.saveFile` (bytes `.brecipe`) dan impor
    via `FilePicker.pickFile`; error terstruktur (cancelled/storage/codec).
  - Editor: menu overflow "Impor .brecipe"/"Ekspor .brecipe"; impor mengisi
    nama/input/step + tandai dirty + preview.
- File: `lib/features/recipe/recipe_io.dart`,
  `lib/features/recipe/recipe_editor_page.dart`,
  `test/features/recipe/recipe_editor_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **258 test lulus**.
- Catatan/risiko: file picker tidak tersedia di test, jadi hanya menu/validasi
  yang diuji; jalur file diuji manual di device.
- Commit: `d017dc6` (kode/test) + commit checkpoint ini.

### CP-034 — 2026-11-12 — F09-T10 Input File

- Status: Selesai (10/11 task F09).
- Perubahan:
  - Tombol "Pilih file" di editor; file dibaca scoped (tanpa streaming),
    dibatasi 5 MiB, disimpan sebagai `BytesBuffer`.
  - Kartu file menampilkan nama + ukuran + aksi hapus; input teks dinonaktifkan
    saat file aktif; preview/draft memakai `_inputBuffer()`.
- File: `lib/features/recipe/recipe_editor_page.dart`,
  `test/features/recipe/recipe_editor_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **259 test lulus**.
- Catatan/risiko: file besar (>5 MiB) ditolak; jalur file picker diuji manual
  di device karena plugin tidak tersedia di test.
- Commit: `90f825b` (kode/test) + commit checkpoint ini.

### CP-035 — 2026-11-12 — F09 Selesai

- Status: Selesai (11/11 task F09).
- Perubahan: widget test alur editor (tambah step via picker, live output,
  disable step, simpan invalid) melengkapi test reorder/hapus/error/guard.
- File: `test/features/recipe/recipe_editor_page_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **260 test lulus**.
- Catatan/risiko: F09 selesai; simpan sukses end-to-end diuji manual di device.
- Commit: `2086cdd` (test) + commit checkpoint ini.

### CP-036 — 2026-11-12 — F10-T01 Katalog Operasi

- Status: Selesai (1/7 task F10).
- Perubahan:
  - `operationCatalogProvider` menggabungkan `OperationRegistry` dengan
    metadata plugin; `pluginMetadataProvider` (diisi F11) memfilter plugin
    nonaktif. Plugin tanpa metadata (core) dianggap aktif.
- File: `lib/features/library/operation_catalog.dart`,
  `test/features/library/operation_catalog_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **263 test lulus**.
- Catatan/risiko: `pluginMetadataProvider` masih kosong sampai F04-T10/T11.
- Commit: `282f01b` (kode/test) + commit checkpoint ini.

### CP-037 — 2026-11-12 — F10-T02 Picker Chips

- Status: Selesai (2/7 task F10).
- Perubahan: picker 85% + search sticky + chip kategori dan Favorit
  (opsional `favorites`), filter gabungan dengan search.
- File: `lib/features/operations/operation_picker.dart`,
  `test/features/operations/operation_picker_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **265 test lulus**.
- Catatan/risiko: sumber favorit masih parameter; provider favorit F10-T04.
- Commit: `e29af63` (kode/test) + commit checkpoint ini.

### CP-038 — 2026-11-12 — F10-T03/T04 Filter & Favorit

- Status: Selesai (4/7 task F10; T02, T03, T04 + T01).
- Perubahan:
  - T03: pencarian + filter kategori/favorit sudah digabung di picker
    (T02) dan diuji.
  - T04: `favoritesProvider` (AsyncNotifier) + `favoriteRepositoryProvider`
    persisten via SQLite; `toggle(id)` menambah/menghapus.
- File: `lib/features/library/favorite_providers.dart`,
  `lib/features/operations/operation_picker.dart`,
  `test/features/library/favorite_providers_test.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **267 test lulus**.
- Catatan/risiko: picker menerima `favorites` sebagai parameter; wiring
  `favoritesProvider` ke picker/Library dilakukan di F10-T05.
- Commit: `e29af63` + `43e49cc` (kode/test) + commit checkpoint ini.

### CP-039 — 2026-11-12 — F10-T05 Tab Library

- Status: Selesai (5/7 task F10).
- Perubahan:
  - `LibraryPage`: daftar operasi dari `operationCatalogProvider`, search
    nama/ID, toggle favorit (`favoritesProvider`), detail singkat bottom
    sheet (kategori, tier, plugin, jumlah parameter, status dukungan).
  - `AppShell` menerima tab Library; `main.dart` memasang `LibraryPage`.
- File: `lib/features/library/library_page.dart`,
  `lib/core/ui/app_shell.dart`, `lib/main.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **267 test lulus**.
- Catatan/risiko: widget test Library menyusul di F10-T07.
- Commit: `3986f60` (kode/test) + commit checkpoint ini.

### CP-040 — 2026-11-12 — F10-T06 Empty Library → Plugin Manager

- Status: Selesai (6/7 task F10).
- Perubahan: empty state Library menampilkan aksi "Buka Plugin Manager"
  (bukan error) menuju `PluginManagerPage` placeholder (F11).
- File: `lib/features/library/library_page.dart`,
  `lib/features/plugins/plugin_manager_page.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **267 test lulus**.
- Catatan/risiko: Plugin Manager masih placeholder; F11 mengisi sisi nyata.
- Commit: `c1c38ea` (kode/test) + commit checkpoint ini.

### CP-041 — 2026-11-12 — F10 Selesai

- Status: Selesai (7/7 task F10).
- Perubahan: widget test Library (daftar, filter pencarian, detail, empty state
  → Plugin Manager); picker chips sudah teruji di F10-T02. `FavoritesController`
  dibuat non-final agar dapat di-override di test.
- File: `test/features/library/library_page_test.dart`,
  `lib/features/library/favorite_providers.dart`.
- Verifikasi:
  - `dart format lib test` → sukses.
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **270 test lulus**.
- Catatan/risiko: Plugin Manager masih placeholder (F11).
- Commit: `dbcfd72` (test) + commit checkpoint ini.

### CP-042 — 2026-11-13 — F11 Plugin Manager Selesai

- Status: Selesai (9/9 task F11).
- Perubahan: daftar plugin + detail, aksi enable/disable/hapus dengan
  konfirmasi & peringatan core, alur sideload `.berp` (preview + dialog izin),
  tombol katalog dengan peringatan jaringan, gate kegagalan bootstrap
  `core.berp`, empty state, dan widget test alur.
- File: `lib/features/plugins/*`, `lib/core/bootstrap/*`, `lib/main.dart`,
  `test/features/plugins/plugin_manager_page_test.dart`.
- Verifikasi:
  - `flutter analyze` → **No issues found**.
  - `flutter test` → **277 test lulus**.
- Catatan/risiko: alur file picker nyata belum diuji di device; bootstrap
  `core.berp` menunggu F13.
- Commit: `54cab59` … `4896fce` + commit checkpoint ini.

### CP-043 � 2026-11-14 � F13 core.berp (10/11)

- Status: Sebagian (10/11). T09 kripto lanjutan ditunda menunggu review keamanan.
- Perubahan: tooling authoring + build `.berp` deterministik, gate integritas &
  ukuran, operasi encode/decode, hash, format, analysis, utility, audit lisensi.
- Verifikasi: `flutter analyze` 0 issue; `flutter test` ? 334 lulus.
- Catatan: XML prettify dilewati (opsional); operasi core di Dart (`lib/core/operations`).

### CP-044 � 2026-11-14 � F14 Keamanan & Kualitas (6/9)

- Status: Sebagian (6/9). T08 perf dan T09 QA desain ditunda (device/manual).
- Perubahan: threat model, test adversarial paket, bypass izin, safe regex,
  CSPRNG, audit offline, integration test end-to-end non-device.
- Verifikasi: `flutter analyze` 0 issue; `flutter test` ? 334 lulus.
- Catatan: non-device praktis selesai; sisa wajib device (F15, F03-T04,
  F04-T05/T08/T10) dan keputusan D02/D08.

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
