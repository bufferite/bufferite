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
| `iwasm` (WAMR 2.4.3, classic interp, EH, ref-types) dengan aset legacy EH | `print` jalan, `pcall` crash |
| Uji minimal `setjmp/longjmp` di WAMR | Crash (access violation) |
| Aset new-EH di WAMR | `unsupported opcode 1f` (`try_table`) |

Kesimpulan: WAMR 2.4.3 hanya mendukung EH legacy dan implementasinya tidak
kompatibel dengan SjLj Lua; WAMR tidak bisa menjadi host.

## Engine yang dipilih: wasmtime (C API)

- Wasmtime ≥ versi yang mendukung exception handling (encoding new/EH).
- C API stabil (`wasmtime.h`), bisa dibungkus Dart FFI tanpa codegen besar.
- WASI preview1, stdout capture, fuel/epoch untuk timeout.
- Lisensi Apache-2.0 WITH LLVM-exception.

## Langkah

1. **Aset Lua** (selesai di spike)
   - Simpan `lua_runtime.wasm` (712.907 byte, SHA-256
     `f7ad57f97fd93b79d3c6a0076bd03023dc7fc13546f2ca3525537c3beb3e5dea`).
   - Dokumentasikan perintah build (wasi-sdk 34 + patch `setsignal`,
     `l_tmpnam`, stub `system`/`tmpfile`).
2. **Build wasmtime C API**
   - Windows: crate `wasmtime-c-api-impl` (versi terbaru) → `wasmtime.dll`.
   - Android: NDK 28.2 + Rust targets (arm64-v8a, armeabi-v7a, x86_64).
   - Verifikasi `print(2+2)` + `pcall(error)` di Windows.
3. **Dart FFI**
   - `wasm_engine_new`, `wasmtime_module_new`, `wasmtime_linker_new`,
     `wasmtime_context_set_wasi`, instantiate, `_start`.
   - Tangkap stdout via `wasi_config` callback; timeout lewat epoch/fuel.
   - Bungkus `SandboxRuntime` + isolate (pola sama dengan CP-057).
4. **Integrasi**
   - Pilih runtime per tier: `lua`/`wasm` memakai engine WASM; DSL tetap Dart.
   - Test: transform, sandbox, timeout, hash mismatch, Android.
   - Perbarui D02, PLUGINS/ARCHITECTURE, THIRD_PARTY_LICENSES.

## Risiko

- Ukuran APK bertambah (engine native + 0,7 MB Lua WASM).
- Cross-compile wasmtime untuk Android butuh Rust targets + NDK (berat).
- Callback stdout C→Dart perlu `NativeCallable`; jika gagal, pakai pipe/preopen
  file untuk output.
- Fallback D07 (1.0 DSL+Lua FFI) tetap berlaku bila port tidak selesai.
