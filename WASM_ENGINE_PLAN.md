# Rencana Port Engine WASM (F05 lanjutan)

Status: direncanakan. Lua saat ini berjalan lewat `lua_dart` (FFI) dengan
isolate + timeout; tier WASM belum punya engine.

## Kenapa bukan `wasm_run`

- `wasm_run` 0.2.0 membawa **wasmtime 14** yang tidak mendukung
  wasm exception-handling (EH).
- Lua membutuhkan setjmp/longjmp → wasm-EH saat dikompilasi ke WASI.
- `wasmi` juga belum mendukung EH.
- Menaikkan wasmtime di `wasm_run` berarti porting ±250 pemakaian API
  (wasmtime 14 → 50+), bukan sekadar ganti versi.

## Engine yang dipilih: WAMR

- Ringan (~60 KB interpreter, ~21 KB libc-wasi), mendukung Android/Windows,
  WASI, dan **exception handling**.
- Lisensi Apache-2.0 + LLVM exception (kompatibel dengan MIT app).
- C API stabil; bisa dibungkus Dart FFI tanpa codegen besar.

## Langkah

1. **Toolchain Lua EH**
   - Unduh wasi-sdk (Windows, ~620 MB) atau gunakan clang-20 + sysroot.
   - Build: `clang --target=wasm32-wasi -O2 -mllvm -wasm-enable-sjlj ...`
     dengan patch `setsignal` dan `l_signalT` (sudah dicoba di zig; backend
     zig gagal, jadi wajib clang wasi-sdk).
   - Hasil: `assets/lua_runtime.wasm` + SHA-256 dipin.
2. **Build WAMR**
   - Windows: CMake + MSVC, `WAMR_BUILD_WASI=1`, EH aktif.
   - Android: NDK 28.2 (sudah terpasang) + CMake, ABI arm64-v8a,
     armeabi-v7a, x86_64.
   - Hasil: `wasm_engine.dll` / `libwasm_engine.so` per ABI.
3. **Dart FFI**
   - Init runtime, load module, instantiate, `wasm_application_execute_main`
     dengan argv `lua -e <script>`.
   - Tangkap stdout (callback `os_printf`/fd_write) dan error.
   - Bungkus sebagai `SandboxRuntime` + isolate + interrupt.
4. **Integrasi & verifikasi**
   - Ganti `LuaRuntime` FFI-lua dengan engine WASM (atau pilih per tier).
   - Test: Lua transform, sandbox, timeout, hash mismatch, Android.
   - Perbarui D02, PLUGINS/ARCHITECTURE, dan THIRD_PARTY_LICENSES.

## Risiko

- Ukuran APK bertambah (engine + Lua WASM).
- WAMR WASI stdout perlu hook platform; belum divalidasi.
- Build cross-ABI menambah waktu rilis; jadwalkan di luar jalur 1.0
  (D07: fallback 1.0 DSL-only bila belum siap).
