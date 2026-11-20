# architecture.md — Bufferite Architecture

Versi dokumen: 1.1
Status: Final (MVP)

## 1. Prinsip Arsitektur
- Inti minimal: aplikasi = plugin interpreter + recipe engine + UI.
- Tidak ada operasi hardcoded; semua operasi adalah plugin (termasuk
  core.berp).
- Offline-first, privacy-first, sandbox-first.
- Kontrak plugin versioned dan stabil.
- Graceful degradation: plugin tidak tersedia = "unsupported", bukan crash.
- Integritas berlapis: runtime WASM di-pin hash; paket .berp diverifikasi
  hash.

## 2. Peta Lapisan (tekstual)
+-------------------------------------------------------------+
| UI Layer                                                     |
| Home | Recipe Editor | Operation Picker | Plugin Manager     |
+-------------------------------------------------------------+
| Application Layer                                            |
| Recipe Engine | Pipeline Executor | Plugin Manager Service   |
+-------------------------------------------------------------+
| Domain Layer                                                 |
| Operation Contract | Recipe Model | Buffer Model | Error     |
+-------------------------------------------------------------+
| Runtime Layer                                                |
| DSL Engine | Lua native/WASM Runtime | WASM Runtime | Sandbox      |
+-------------------------------------------------------------+
| Data Layer                                                   |
| Recipe Store (SQLite) | Plugin Store | Settings | Asset Core |
+-------------------------------------------------------------+
| Platform Layer                                               |
| Flutter (Android/iOS) | Isolate | File System | Secure Store |
+-------------------------------------------------------------+

## 3. Struktur Folder (feature-first)
lib/
  core/
    engine/          (recipe engine, pipeline executor)
    plugin/          (loader, manifest, registry, verifier)
    runtime/         (dsl, lua native, lua wasm, wasm, sandbox)
    registry/        (model, signature, client, installer, trust store; F16)
    storage/         (sqlite, settings)
    ui/              (tema, komponen shared)
    error/
  features/
    recipe/
    operations/
    library/
    plugins/
    settings/
  assets/
    core.berp        (plugin core dibundel)
    lua_runtime.wasm (interpreter Lua, hash di-pin)

## 4. Alur Data
Input Buffer -> Pipeline Executor -> [Operation 1] -> [Operation 2] -> ...
-> Output Buffer
- Setiap Operation dieksekusi sesuai runtime tier-nya (dsl/lua/wasm).
- Pipeline berjalan di worker isolate; UI menerima stream hasil (preview live).
- Error per step dibungkus (pluginId, stepId) dan tidak menghentikan UI.
- Step dengan enabled=false dilewati.
- Step dengan operasi "unsupported" dilewati dengan peringatan.

## 5. Alur Bootstrap
1. App start -> cek apakah core.berp sudah terinstal.
2. Jika belum -> verifikasi SHA-256 core.berp dari aset -> instal otomatis.
3. Muat manifest core.berp -> daftarkan operasi ke Operation Picker.
4. Runtime Lua: default `lua_dart` (native). Jika engine WASM dipilih,
   verifikasi SHA-256 `lua_runtime.wasm` sebelum instantiasi.
5. Siap dipakai; katalog plugin read-only dan sideload tersedia di
   Plugin Manager.
6. Jika core.berp gagal verifikasi -> tampilkan error jelas; aplikasi tetap
   terbuka dengan empty state yang mengarahkan ke reinstalasi/sideload.

## 6. Kontrak Operasi (ringkas)
abstract class Operation {
  String get id;
  String get name;
  OperationCategory get category;
  List<OperationParam> get params;
  OperationIO get io;
  Future<Buffer> execute(Buffer input, Map<String, dynamic> args);
}
- Semua operasi (core maupun komunitas) mengikuti kontrak ini.
- Perbedaan hanya pada runtime eksekusi.
- Detail lengkap di operations.md.

## 7. Skema Recipe
Skema JSON recipe v1: `schemaVersion`, `id`, `name`, `steps`, `input`,
`output`, `meta`. Perubahan skema menaikkan `schemaVersion`. Detail lengkap
di `operations.md` §8.

Implementasi MVP:
- Model: `lib/features/recipe/recipe.dart` (`Recipe`, `RecipeStep`,
  `RecipeMeta`, validasi).
- Codec `.brecipe`: `lib/features/recipe/recipe_codec.dart` (batas 5 MiB,
  migrasi schema, validasi sebelum dipakai).
- `output` adalah cache; codec tidak mengekspornya dan tidak mempercayainya
  saat impor.
- Input `file` ditolak di `.brecipe` v1; file harus dimaterialisasi engine
  sebelum masuk pipeline.

Implementasi engine MVP:
- `PipelineExecutor` (`lib/core/engine/pipeline_executor.dart`) menerima
  `PipelineStep` dari core, sehingga engine tidak bergantung pada model
  Recipe di layer feature. Jembatan `Recipe.toPipelineSteps()` ada di
  `lib/features/recipe/recipe_pipeline.dart`.
- Event live membawa output tiap step; error dibungkus `pluginId`/`stepId`.
  Kebijakan default `stop` (D06); lanjut dengan output terakhir hanya opt-in.
- Pipeline berjalan di host isolate pekerja (request/response/progress,
  cancel/timeout) sejak CP-054.

Implementasi plugin MVP:
- Manifest v1: `lib/core/plugin/plugin_manifest.dart`; semver tanpa
  dependency tambahan di `semantic_version.dart`; izin `cpu`, `net`,
  `file:read`, `file:write` di `plugin_permission.dart`.
- Paket `.berp`: `plugin_package.dart` memvalidasi zip sebelum ekstraksi
  (path traversal, symlink, duplikat, jumlah entri, ukuran per entri/total,
  dan ukuran manifest). Batas detail ada di `PLUGINS.md` §6.
- Integritas SHA-256: `plugin_integrity.dart`; metadata terpasang:
  `installed_plugin.dart`; registrasi operasi manifest:
  `manifest_registrar.dart`; siklus enable/disable/hapus:
  `plugin_lifecycle.dart`.
- Sideload UI (F04-T05), bootstrap aset `core.berp` (F04-T08), dan
  `PluginManagerService`/provider (F04-T10) sudah tersedia.
- Registry daring (F16): model `registry.json`, signature Ed25519, trust
  store, tooling build/sign/verify (F16-T08), client read-only HTTPS + cache +
  sequence + fallback offline (F16-T01), UI katalog + konsen + instalasi
  terverifikasi (F16-T02), update/rollback + badge versi (F16-T04), serta
  trust anchor produksi + custody kunci (F16-T03/D13) sudah tersedia. Hosting
  GitHub Pages sudah diputuskan (D12). Signing indeks dilakukan offline; kunci
  paket di secret CI. Publikasi CI masih menunggu repo/Pages/secret. Spesifikasi
  di `REGISTRY.md`; modul di `lib/core/registry/`,
  `lib/features/plugins/registry/`, `tool/registry_cli.dart`, dan scaffold repo
  di `registry-scaffold/`.

Implementasi storage MVP:
- `AppDatabase` (`lib/core/storage/app_database.dart`) membuka SQLite dengan
  `PRAGMA foreign_keys = ON`, schema v1, dan migrasi berantai.
- Tabel v1: `recipe`, `plugin`, `setting`, `favorite`, dan
  `plugin_permission` (foreign key ke `plugin`, cascade saat plugin dihapus).
- Factory dan path dapat diinjeksi; test memakai `sqflite_common_ffi` tanpa
  device.
- Repository: `RecipeRepository` (`lib/features/recipe/recipe_repository.dart`),
  `PluginRepository` (`lib/features/plugins/plugin_repository.dart`),
  `SettingsRepository` (`lib/features/settings/settings_repository.dart`), dan
  `FavoriteRepository` (`lib/features/library/favorite_repository.dart`).
  Data JSON menjadi sumber kebenaran; kolom terpisah dipakai untuk query dan
  status.
- `SettingsRepository` memakai default aman: tema system, bahasa Indonesia,
  timeout 2 detik, memori 64 MiB, log opt-in false, konsen registry false;
  nilai rusak jatuh ke default per-key.
- `PluginPackageStore` (`lib/core/plugin/plugin_package_store.dart`) menulis
  paket ke `<root>/<pluginId>/<version>` lewat direktori staging + rename
  atomik; staging dibersihkan saat gagal dan uninstall.

## 8. Keamanan & Sandbox
- Runtime WASM di-pin SHA-256; mismatch = tolak eksekusi.
- Paket .berp diverifikasi SHA-256 sebelum instalasi.
- Registry resmi menambahkan signature Ed25519 untuk indeks dan paket
  (`REGISTRY.md` §5); public key di-pin di aplikasi. Paket diverifikasi
  sebelum `.berp` dibuka, dan provenance disimpan di metadata plugin.
- Izin Android `INTERNET` ada di manifest sejak Fase 2; aplikasi tidak
  melakukan request sebelum konsen dan konsen dapat dicabut di Settings.
- Izin: cpu (default), net, file:read, file:write; dialog eksplisit untuk
  selain cpu.
- Batas waktu dan memori per eksekusi.
- Tanpa akses net/fs kecuali izin disetujui.
- Regex engine wajib aman dari ReDoS (batas waktu).
- CSPRNG untuk operasi acak.
- Kontrak sandbox: `lib/core/runtime/sandbox.dart`. Default timeout 2 detik,
  memori 64 MiB, dan izin `cpu`; override dilakukan lewat `SandboxConfig`.
  `SandboxContext` membawa identitas plugin/operasi/step, izin aktif, dan
  token pembatalan. Runtime DSL/Lua/WASM wajib mengimplementasikan
  `SandboxRuntime` dan memeriksa konteks sebelum side effect.

## 9. State Management & DI
- Riverpod untuk state management.
- Dependency injection via Provider/Riverpod; hindari singleton mutable.
- Pipeline executor berjalan di isolate; komunikasi via port/stream.
- Lokalisasi UI memakai katalog JSON `assets/i18n/{id,en}.json`.
  `AppLocalizations.preload()` memuat katalog sekali sebelum `runApp`,
  `AppLocalizationsScope` menyediakan `context.tr`/`context.trPlural`, dan
  `LanguageController` menyimpan bahasa aktif lewat `SettingsRepository`
  (key `language`).
- Metadata operasi inti dan pesan error umum diterjemahkan di lapisan
  presentasi (`operation_localization.dart`, `localized_error.dart`) dengan
  fallback ke metadata manifest/pesan domain agar plugin pihak ketiga tetap
  tampil.

## 10. Keputusan Terkunci
- Inti minimal; semua operasi plugin.
- core.berp dibundel, diinstal otomatis, di-hash.
- Runtime: DSL + Lua + WASM (satu kesatuan MVP).
  Catatan 1.0: Lua memakai `lua_dart` (FFI native) dengan capability sandbox
  sebagai default; engine Lua WASM (wasmtime C API + `lua_runtime.wasm`)
  sudah tersedia dan tervalidasi di Windows/Android, dengan cache runtime +
  worker persisten (F05-T08/CP-064). Tier plugin `wasm` memakai ABI command
  WASI v1 (`WasmPluginRuntime`): input via stdin, args JSON di argv, output
  stdout, tanpa preopen/socket (F05-T06/CP-065). Libwasmtime baru dikemas di
  varian debug Android, jadi tier `wasm`/`LuaEngine.wasm` di release 1.0
  menunggu library ikut dirilis.
- Format paket: .berp.
- Sideload didukung di MVP.
- Signature: sideload cukup SHA-256; registry resmi wajib signature Ed25519
  untuk indeks + paket (Fase 2, `REGISTRY.md`).
- Registry read-only: satu registry resmi, trust anchor kunci di aplikasi,
  tanpa sinkronisasi latar belakang (D12/D13 selesai). UI katalog, konsen, dan
  instalasi memakai `RegistryInstaller` + `PluginManagerService`.
- Interpreter Lua via WASM dijalankan dengan wasmtime C API (FFI) di worker
  isolate persisten; `wasi_config` (stdout/stderr file, stdin bytes) + epoch
  untuk timeout. Engine + modul dikompilasi sekali per plugin.

## 11. Pertanyaan Terbuka
- Streaming end-to-end berbasis chunk belum ada; input file dimaterialisasi
  bertahap di worker isolate dengan batas memori (F16-T05 selesai).
- Custody/rotasi kunci Ed25519 (D13) selesai: kunci indeks offline, kunci
  paket di CI; detail di `REGISTRY.md` §5.3/§12. Publikasi CI menunggu
  operasional repo/Pages/secret. Hosting/URL registry (D12) sudah selesai.
- Ukuran `core.berp` sudah diputuskan (D03: 2 MiB, pecah per kategori bila
  melewati).

## 12. Dependency Inti & Alasan

Setiap dependency langsung wajib punya alasan dan alternatif yang
dipertimbangkan. Dependency baru harus ditambahkan ke tabel ini sebelum
dipakai di kode.

| Package | Digunakan untuk | Alasan | Alternatif yang ditolak |
|---|---|---|---|
| `flutter_riverpod` | State management & DI | Diwajibkan `AGENT.md`; testable, tanpa singleton mutable | `provider` (kurang terstruktur untuk async), `bloc` (boilerplate lebih besar) |
| `crypto` | SHA-256, HMAC, hash operasi core | API ringkas, didukung luas, cukup untuk hash/HMAC | `pointycastle` (algoritma lebih lengkap, tetapi belum perlu untuk verifikasi hash) |
| `cryptography` | Ed25519 sign/verify registry (F16-T08) | Implementasi Ed25519 murni Dart, API signature ringkas, lolos test vector RFC 8032 | `pointycastle` (belum menyediakan Ed25519), binding native (menambah platform/dependency) |
| `archive` | Baca/tulis zip `.berp` | Mendukung zip encode/decode murni Dart | `zip`/`archive_io` (API lebih terbatas atau tidak perlu) |
| `path_provider` | Direktori database dan paket plugin | Standar Flutter untuk path aplikasi lintas platform | Platform channel manual (reinventing) |
| `sqflite` | Recipe, plugin, settings store | Sesuai `ARCHITECTURE.md` (SQLite); ringan, tanpa codegen | `drift` (codegen + build step), `isar` (binary DB, bukan SQLite) |
| `lua_dart` | Runtime tier `lua` (default 1.0) | Lua 5.5.1 siap pakai via FFI; sandbox + batas memori didukung | Interpreter Dart murni (belum ada yang stabil), Lua WASM (butuh engine native + ukuran) |
| `ffi` | Binding wasmtime C API untuk engine Lua WASM | C API stabil, tanpa codegen besar; bisa dipakai lintas desktop/Android | `wasm_run` (tidak mendukung wasm-EH), `wasmer` (build berat) |
| `file_picker` | Sideload `.berp` dan impor `.brecipe` | Mendukung Android/iOS/desktop, scoped user pick | Platform channel manual per OS |
| `sqflite_common_ffi` (dev) | Test storage tanpa device | Menjalankan SQLite di host/CI | Mock repository (tidak menguji SQL/migrasi) |

Catatan:

- `cupertino_icons` dari template Flutter dihapus karena belum dipakai.
- Dependency transitif tidak dicatat di sini; yang dicatat adalah dependency
  langsung di `pubspec.yaml`.
- Penambahan dependency untuk Fase 2 (signature Ed25519) sudah melalui
  review: `package:cryptography` 2.9.0 (pure Dart, Ed25519) ditambahkan untuk
  tooling registry F16-T08 dan dipakai verifikasi client F16-T03.
  `pointycastle` 4.0.0 belum menyediakan Ed25519. Test vector RFC 8032 ada di
  `test/core/registry/registry_signature_test.dart`. Custody kunci produksi
  mengikuti D13: kunci indeks offline/air-gapped, kunci paket di secret CI,
  bukan file repo.
