# Bangun fixture WASM untuk test tier `wasm`.
#
#   powershell -File tool/build_wasm_fixtures.ps1
#
# Butuh wasi-sdk (default: build/wasm-spike/wasi-sdk). Set $env:WASI_SDK
# untuk memakai lokasi lain.

$ErrorActionPreference = 'Stop'

$sdk = if ($env:WASI_SDK) {
  (Resolve-Path $env:WASI_SDK).Path
} else {
  (Resolve-Path 'build/wasm-spike/wasi-sdk/wasi-sdk-34.0-x86_64-windows').Path
}
$clang = Join-Path $sdk 'bin/clang.exe'
$sysroot = Join-Path $sdk 'share/wasi-sysroot'
if (-not (Test-Path $clang)) {
  throw "clang tidak ditemukan: $clang"
}

$out = Join-Path $PSScriptRoot '..\test\fixtures\wasm'
$out = (Resolve-Path $out).Path
$names = @('echo_upper', 'fs_probe', 'exit_error', 'spin', 'argv_probe', 'spin_if', 'stdout_flood')

foreach ($name in $names) {
  & $clang '--target=wasm32-wasip1' "--sysroot=$sysroot" '-Os' `
    '-Wl,--strip-all' '-o' "$out\$name.wasm" "$out\$name.c"
  if ($LASTEXITCODE -ne 0) {
    throw "gagal membangun $name"
  }
}

# Modul dengan import host yang tidak disediakan linker.
& $clang '--target=wasm32-wasip1' "--sysroot=$sysroot" '-Os' `
  '-Wl,--strip-all' '-Wl,--allow-undefined' `
  '-o' "$out\host_import.wasm" "$out\host_import.c"
if ($LASTEXITCODE -ne 0) {
  throw 'gagal membangun host_import'
}

Get-ChildItem "$out\*.wasm" | Select-Object Name, Length
