#!/usr/bin/env pwsh
# Bangun libwasmtime.so untuk Android (arm64-v8a, x86_64) dari crate
# wasmtime-c-api-impl di build/wasm-spike/wasmtime-capi.
#
# Prasyarat (lihat WASM_ENGINE_PLAN.md):
# - rustup target add aarch64-linux-android x86_64-linux-android
# - NDK 28.x, path lewat -Ndk atau $env:ANDROID_NDK_HOME
# - crate sudah dipatch: [lib] name="wasmtime", crate-type=["cdylib"]
#
# Hasil disalin ke android/app/src/debug/jniLibs/<abi>/libwasmtime.so
# (khusus varian debug; folder tersebut di-.gitignore). Pindahkan ke src/main
# saat engine WASM menjadi default di 1.1.
param(
  [string]$Ndk = $env:ANDROID_NDK_HOME,
  [string]$Api = '24',
  [string]$Crate = ''
)

$ErrorActionPreference = 'Stop'

if (-not $Ndk) {
  throw 'NDK tidak ditemukan. Set ANDROID_NDK_HOME atau pakai -Ndk <path>.'
}

$root = Split-Path -Parent $PSScriptRoot
if (-not $Crate) {
  $Crate = Join-Path $root 'build/wasm-spike/wasmtime-capi'
}
if (-not (Test-Path (Join-Path $Crate 'Cargo.toml'))) {
  throw "Crate wasmtime C API tidak ada di $Crate (lihat WASM_ENGINE_PLAN.md)."
}

$bin = Join-Path $Ndk 'toolchains/llvm/prebuilt/windows-x86_64/bin'
$strip = Join-Path $bin 'llvm-strip.exe'
$jniLibs = Join-Path $root 'android/app/src/debug/jniLibs'

$targets = [ordered]@{
  'aarch64-linux-android' = 'arm64-v8a'
  'x86_64-linux-android'  = 'x86_64'
}

foreach ($target in $targets.Keys) {
  $abi = $targets[$target]
  $linker = Join-Path $bin "$target$Api-clang.cmd"
  $envName = ($target -replace '-', '_')
  Set-Item -Path "Env:CARGO_TARGET_$($target.ToUpper() -replace '-', '_')_LINKER" -Value $linker
  Set-Item -Path "Env:CC_$envName" -Value $linker
  Set-Item -Path "Env:AR_$envName" -Value (Join-Path $bin 'llvm-ar.exe')

  Write-Host "==> build $target ($abi)"
  cargo build --release --target $target `
    --features 'wasi cranelift gc gc-drc' `
    --manifest-path (Join-Path $Crate 'Cargo.toml')
  if ($LASTEXITCODE -ne 0) {
    throw "cargo build gagal untuk $target."
  }

  $so = Join-Path $Crate "target/$target/release/libwasmtime.so"
  & $strip --strip-unneeded $so
  if ($LASTEXITCODE -ne 0) {
    throw "llvm-strip gagal untuk $target."
  }

  $dest = Join-Path $jniLibs "$abi/libwasmtime.so"
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
  Copy-Item $so $dest -Force
  Write-Host "    -> $dest"
}

Write-Host 'Selesai.'
