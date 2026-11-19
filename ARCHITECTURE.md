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
    registry/        (rencana F16: client, signature, trust store)
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
5. Siap dipakai; katalog plugin (rencana Fase 2) dan sideload tersedia di
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
- Registry daring (F16) belum diimplementasikan; spesifikasi di
  `REGISTRY.md`. Rencana modul: `lib/core/registry/` + UI di
  `lib/features/plugins/registry/`.

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
- `SettingsRepository` memakai default aman: tema system, timeout 2 detik,
  memori 64 MiB, log opt-in false; nilai rusak jatuh ke default per-key.
- `PluginPackageStore` (`lib/core/plugin/plugin_package_store.dart`) menulis
  paket ke `<root>/<pluginId>/<version>` lewat direktori staging + rename
  atomik; staging dibersihkan saat gagal dan uninstall.

## 8. Keamanan & Sandbox
- Runtime WASM di-pin SHA-256; mismatch = tolak eksekusi.
- Paket .berp diverifikasi SHA-256 sebelum instalasi.
- Registry resmi menambahkan signature Ed25519 untuk indeks dan paket
  (rencana F16; `REGISTRY.md` §5); public key di-pin di aplikasi.
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
  tanpa sinkronisasi latar belakang (D12/D13 terbuka).
- Interpreter Lua via WASM dijalankan dengan wasmtime C API (FFI) di worker
  isolate persisten; `wasi_config` (stdout/stderr file, stdin bytes) + epoch
  untuk timeout. Engine + modul dikompilasi sekali per plugin.

## 11. Pertanyaan Terbuka
- Streaming untuk file besar (F16-T05).
- Hosting/URL registry (D12) dan custody kunci Ed25519 (D13); detail di
  `REGISTRY.md` §12.
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
- Penambahan dependency untuk Fase 2 (signature Ed25519) harus melalui
  review keamanan dan pembaruan tabel ini. Kandidat: `package:cryptography`
  (pure Dart, mendukung Ed25519); `pointycastle` 4.0.0 belum menyediakan
  Ed25519. Belum ditambahkan ke `pubspec.yaml`.
