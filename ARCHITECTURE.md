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
| DSL Engine | Lua via WASM Runtime | WASM Runtime | Sandbox    |
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
    runtime/         (dsl, lua_wasm, wasm, sandbox)
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
- Eksekusi berjalan di isolate; UI menerima stream hasil (preview live).
- Error per step dibungkus (pluginId, stepId) dan tidak menghentikan UI.
- Step dengan enabled=false dilewati.
- Step dengan operasi "unsupported" dilewati dengan peringatan.

## 5. Alur Bootstrap
1. App start -> cek apakah core.berp sudah terinstal.
2. Jika belum -> verifikasi SHA-256 core.berp dari aset -> instal otomatis.
3. Muat manifest core.berp -> daftarkan operasi ke Operation Picker.
4. Runtime Lua: verifikasi SHA-256 lua_runtime.wasm sebelum instantiasi.
5. Siap dipakai; katalog plugin dan sideload tersedia di Plugin Manager.
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
  Kebijakan default tetap stop sambil menunggu D06.
- Eksekusi masih berjalan di isolate pemanggil. Host isolate pekerja
  (request/response/progress) menyusul setelah runtime plugin F05 tersedia
  (F03-T04).

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
- Belum diimplementasikan: alur sideload UI (F04-T05), bootstrap aset
  `core.berp` (F04-T08), dan `PluginManagerService`/provider (F04-T10).

## 8. Keamanan & Sandbox
- Runtime WASM di-pin SHA-256; mismatch = tolak eksekusi.
- Paket .berp diverifikasi SHA-256 sebelum instalasi.
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
- Runtime: DSL + Lua via WASM + WASM (satu kesatuan MVP).
- Format paket: .berp.
- Sideload didukung di MVP.
- Signature opsional di MVP, wajib untuk registry resmi di Fase 2.
- Interpreter Lua via WASM dijalankan dengan wasm_run di isolate.

## 11. Pertanyaan Terbuka
- Finalisasi interpreter Lua yang dikompilasi ke WASM.
- Strategi cache runtime untuk banyak plugin.
- Ukuran maksimum core.berp dan strategi lazy load operasi.
- Streaming untuk file besar (Fase 2).

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
| `wasm_run` | Menjalankan runtime Lua/WASM | Diwajibkan `ARCHITECTURE.md` dan `PLUGINS.md` | `wasmer`/FFI native (kompleksitas build lintas platform) |
| `file_picker` | Sideload `.berp` dan impor `.brecipe` | Mendukung Android/iOS/desktop, scoped user pick | Platform channel manual per OS |
| `sqflite_common_ffi` (dev) | Test storage tanpa device | Menjalankan SQLite di host/CI | Mock repository (tidak menguji SQL/migrasi) |

Catatan:

- `cupertino_icons` dari template Flutter dihapus karena belum dipakai.
- Dependency transitif tidak dicatat di sini; yang dicatat adalah dependency
  langsung di `pubspec.yaml`.
- Penambahan dependency untuk Fase 2 (mis. signature Ed25519) harus melalui
  review keamanan dan pembaruan tabel ini.
