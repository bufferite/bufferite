# Bufferite

Racik data dengan resep. Susun operasi, olah buffer, dapatkan hasil.

Bufferite adalah aplikasi mobile (Flutter) yang pada dasarnya adalah
plugin interpreter + recipe engine + UI. Semua operasi pengolahan data—
encode/decode, encrypt/decrypt, konversi format, analisis data—adalah
plugin, termasuk paket core yang dibundel. Aplikasi berjalan offline secara
default dan menjaga privasi: data tidak keluar dari device kecuali pengguna
menyetujui izin eksplisit.

## Fitur
- Recipe builder: drag and drop operasi, reorder, enable/disable, preview
  live.
- Plugin-first: semua operasi adalah plugin (.berp). Inti aplikasi kecil
  dan cepat.
- Offline & privacy-first: tanpa akses jaringan secara default.
- Sandbox: plugin berjalan dengan batas resource; runtime WASM di-pin hash.
- Sideload: instal plugin dari file .berp lokal untuk pengembangan.
- Core pack: core.berp berisi hampir semua operasi CyberChef, diinstal
  otomatis saat first-run.

## Arsitektur Singkat
- Inti: recipe engine, pipeline executor, plugin loader, runtime
  (DSL/Lua via WASM/WASM), sandbox, storage, UI.
- Operasi: semua plugin (termasuk core.berp).
- Paket plugin: .berp (zip berisi manifest + entrypoint + aset).
- Verifikasi: SHA-256 untuk runtime WASM dan paket .berp.

## Struktur Repo
lib/
  core/        (engine, plugin, runtime, storage, ui, error)
  features/    (recipe, operations, library, plugins, settings)
  assets/      (core.berp, lua_runtime.wasm)
docs/
  agent.md
  architecture.md
  plugins.md
  operations.md
  design.md
  roadmap.md
  README.md
  CONTRIBUTING.md

## Cara Build & Run
1. Pastikan Flutter SDK terpasang.
2. flutter pub get
3. flutter run
4. Untuk build rilis: flutter build apk / flutter build ios

## Dokumentasi
- architecture.md — layer, alur data, bootstrap, keamanan.
- plugins.md — sistem plugin, tier, izin, integritas WASM, registry.
- operations.md — kontrak Operation dan isi core.berp.
- design.md — design system, komponen, wireframe, aksesibilitas.
- roadmap.md — fase dan prioritas.
- agent.md — aturan kerja AI agent.
- TODO.md — backlog task per fitur.
- progress.md — checkpoint progres implementasi.
- CONTRIBUTING.md — panduan kontribusi.

## Lisensi
TBD (rekomendasi: MIT untuk inti dan core.berp; plugin komunitas mengikuti
lisensi masing-masing).

## Status
MVP dalam pengembangan. Lihat roadmap.md untuk detail fase.
