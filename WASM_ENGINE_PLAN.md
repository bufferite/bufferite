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
   - Windows: **selesai** — `wasmtime.dll` 48.0.9 (14,9 MB) +
     harness C; `print`/`pcall` lulus.
   - Android: NDK 28.2 + Rust targets (arm64-v8a, armeabi-v7a, x86_64).
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
