# Rencana Port Engine WASM (F05 lanjutan)

Status: **spike selesai (2026-11-19)**. Aset Lua→WASM terbukti valid; engine
host yang dipilih berubah dari WAMR ke **wasmtime C API** karena WAMR belum
mendukung encoding EH yang dipakai Lua. 1.0 tetap memakai `lua_dart`.

## Hasil spike

| Uji | Hasil |
|---|---|
| Build Lua 5.4.8 → `wasm32-wasip1` + EH (`wasi-sdk 34`, `-mllvm -wasm-enable-sjlj -mllvm -wasm-use-legacy-eh=false`) | Berhasil, 712.907 byte |
| `print(2+2)` di Node 24 (WASI + `--experimental-wasm-exnref`) | `4` |
| `pcall(error)` di Node | `false  boom` (exit 0) |
| `iwasm` (WAMR 2.4.3) | legacy EH crash; aset new-EH `unsupported opcode 1f` |
| **wasmtime C API 48.0.9 (`wasi`, `cranelift`, `gc`, `gc-drc`)** | **`print` → 4; `pcall` → `false boom`, exit 0** |

Kesimpulan: aset Lua valid (Node + wasmtime). WAMR tidak bisa menjadi host;
**wasmtime C API terbukti bisa** di Windows.

## Engine yang dipilih: wasmtime (C API)

- Terbukti menjalankan aset Lua EH di Windows (lihat tabel).
- Fitur Rust yang wajib: `wasi`, `cranelift`, `gc`, `gc-drc`
  (config `wasm_exceptions` digerbangi fitur `gc`; engine menuntut kolektor).
- C API stabil (`wasmtime.h`), bisa dibungkus Dart FFI tanpa codegen besar.
- WASI preview1, `wasi_config_set_stdout_custom` untuk capture output,
  epoch/fuel untuk timeout.
- Lisensi Apache-2.0 WITH LLVM-exception.

## Langkah

1. **Aset Lua** (selesai di spike)
   - Simpan `lua_runtime.wasm` (712.907 byte, SHA-256
     `f7ad57f97fd93b79d3c6a0076bd03023dc7fc13546f2ca3525537c3beb3e5dea`).
   - Dokumentasikan perintah build (wasi-sdk 34 + patch `setsignal`,
     `l_tmpnam`, stub `system`/`tmpfile`).
2. **Build wasmtime C API**
   - Windows: **selesai** — `wasmtime.dll` 48.0.9 (14,9 MB) + harness C;
     `print`/`pcall` lulus.
   - Android: **selesai (CP-063)** — NDK 28.2 + Rust targets
     `aarch64-linux-android` dan `x86_64-linux-android` (API 24).
     Hasil di-strip: `arm64-v8a` 11,4 MB, `x86_64` 14,8 MB. Skrip:
     `tool/build_wasmtime_android.ps1` → `android/app/src/debug/jniLibs/`
     (di-`.gitignore`, tidak di-commit; hanya varian debug agar APK rilis 1.0
     tidak membawa engine yang belum dipakai). `armeabi-v7a` dilewati:
     cranelift tidak mendukung ARM 32-bit.
3. **Dart FFI** — **selesai (Windows + Android)**
   - `wasmtime_ffi.dart` (binding), `wasmtime_engine.dart` (engine/modul/
     WASI/epoch), `wasm_lua_runtime.dart` (`SandboxRuntime` + isolate).
   - Skrip transform dipakai bersama (`lua_program.dart`) agar semantik
     tier `lua` dan `wasm` identik.
   - stdout/stderr ditangkap lewat **file sementara** karena callback
     `wasi_config_set_stdout_custom` dipanggil dari thread non-isolate
     (`NativeCallable.isolateLocal` crash: "Cannot invoke native callback
     outside an isolate"). Rencana berikutnya: `NativeCallable.listener`
     atau pipe.
   - Timeout/pembatalan: isolate utama memanggil
     `wasmtime_engine_increment_epoch` pada alamat engine; deadline store = 1.
   - Verifikasi: 7 test engine + 12 test runtime (transform, args, unicode,
     sandbox, error, timeout, cancel) lulus di Windows; integration test
     eksekusi + timeout lulus di emulator Android x86_64 (JIT cranelift
     berjalan).
4. **Integrasi**
   - `PluginRuntimeLoader` + `SandboxOperation`: executor nyata untuk tier
     `dsl`/`lua` dan verifikasi hash entrypoint. `LuaEngine.native` tetap
     default 1.0; `LuaEngine.wasm` siap dipakai. Tier `wasm` masih tanpa
     executor sampai ABI-nya ditetapkan.
   - Cache runtime per plugin (LRU 4, idle 5 menit) + worker WASM persisten:
     engine/modul dikompilasi sekali, store WASI baru tiap eksekusi, dispose
     saat idle/disable/hapus (F05-T08/CP-064).
   - Aset `assets/lua_runtime.wasm` dibundel; `loadLuaWasmModule` memeriksa
     pin SHA-256 sebelum modul dipakai.
   - Test: transform, sandbox, timeout, hash mismatch, kontrak
     `lua_dart` vs Lua WASM, Android.
   - Sisa: perbarui D02, PLUGINS/ARCHITECTURE, THIRD_PARTY_LICENSES.

## Risiko

- Ukuran APK bertambah (engine native + 0,7 MB Lua WASM).
- Cross-compile wasmtime untuk Android butuh Rust targets + NDK (berat).
- Output WASI harus lewat file sementara (callback lintas thread tidak bisa
  memakai `NativeCallable.isolateLocal`); berpotensi lambat untuk output besar.
- Fallback D07 (1.0 DSL+Lua FFI) tetap berlaku bila port tidak selesai.
