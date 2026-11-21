# Bufferite

Racik data dengan resep. Susun operasi, olah buffer, dapatkan hasil.

Bufferite dibuat karena pengolahan data sering kali memaksa kita mengunggah
file ke layanan orang lain, memasang alat berat di desktop, atau menulis
skrip sekali pakai. Padahal banyak pekerjaan—encode/decode, konversi format,
hash, enkripsi, membersihkan teks—cukup dilakukan di perangkat sendiri.
Bufferite membawa pendekatan "recipe" ke mobile: susun langkah seperti
resep, lihat hasilnya langsung, lalu simpan dan bagikan resepnya.

Filosofinya:

- **Data tetap milik pengguna.** Offline secara default; tidak ada data yang
  keluar dari perangkat tanpa izin eksplisit.
- **Kecil di inti, terbuka di tepi.** Aplikasi hanya berisi engine, sandbox,
  dan UI. Semua operasi adalah plugin yang bisa diperiksa, diganti, atau
  ditambah.
- **Transparan dan bisa diaudit.** Format plugin, hash, dan signature
  terbuka; asal-usul operasi dari registry dapat diverifikasi.
- **Ramah dipakai, ketat di belakang.** Alurnya sesederhana meracik resep,
  sementara runtime membatasi resource dan akses plugin.

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
- Registry (Fase 2): katalog read-only live dengan verifikasi hash + signature
  Ed25519, pencarian/detail, konsen jaringan, instalasi terverifikasi, serta
  update/rollback dan badge revocation. Tooling, client, UI katalog, trust
  anchor, dan signing offline selesai. Spesifikasi di `REGISTRY.md`.
- Core pack: core.berp berisi hampir semua operasi CyberChef, diinstal
  otomatis saat first-run.

## Arsitektur Singkat
- Inti: recipe engine, pipeline executor, plugin loader, runtime
  (DSL, Lua native, Lua WASM, plugin WASM), sandbox, storage, UI.
- Operasi: semua plugin (termasuk core.berp).
- Paket plugin: .berp (zip berisi manifest + entrypoint + aset).
- Verifikasi: SHA-256 untuk runtime WASM dan paket .berp; registry resmi
  menambahkan signature Ed25519 untuk indeks + paket (tooling, client, dan
  instalasi Fase 2; lihat `REGISTRY.md`).

## Struktur Repo
lib/
  core/        (engine, plugin, runtime, storage, ui, error)
  features/    (recipe, operations, library, plugins, settings)
assets/        (core.berp, lua_runtime.wasm)
plugins/       (source operasi core.berp)
registry-scaffold/ (benih repo registry GitHub Pages)
test/          (unit, contract, widget test)
Dokumen proyek berada di root repo:
  README.md, AGENT.md, ARCHITECTURE.md, PLUGINS.md, REGISTRY.md,
  operations.md, DESIGN.md, ROADMAP.md, TODO.md, progress.md,
  THREAT_MODEL.md, WASM_ENGINE_PLAN.md, PRIVACY.md, CONTRIBUTING.md,
  RELEASE_CHECKLIST.md

## Cara Build & Run
1. Pastikan Flutter SDK terpasang.
2. flutter pub get
3. flutter run
4. Untuk build rilis: flutter build apk / flutter build ios

## Dokumentasi
- `ARCHITECTURE.md` — layer, struktur folder, alur data, bootstrap, keamanan.
- `PLUGINS.md` — sistem plugin, tier, izin, integritas, alur instalasi.
- `REGISTRY.md` — spesifikasi registry, signature Ed25519, update/rollback.
- `operations.md` — kontrak Operation, error, dan skema recipe v1.
- `DESIGN.md` — design system, komponen, wireframe, aksesibilitas.
- `ROADMAP.md` — fase dan prioritas.
- `AGENT.md` — aturan kerja AI agent.
- `TODO.md` — backlog task per fitur.
- `progress.md` — checkpoint progres implementasi.
- `THREAT_MODEL.md` — model ancaman dan batas isolasi.
- `PRIVACY.md` — komitmen offline-first dan perilaku jaringan.
- `CONTRIBUTING.md` — panduan kontribusi.

## Lisensi
MIT untuk inti dan core.berp (lihat [LICENSE](LICENSE)). Plugin komunitas
mengikuti lisensi masing-masing.

## Status
MVP 1.0 selesai (tag lokal `v1.0.0`): 131/131 task. Fase 2 selesai 8/8:
tooling registry, client read-only, UI katalog + instalasi terverifikasi,
update/rollback, trust anchor, dan registry live di
`https://bufferite.github.io/plugins` (URL sementara D15) dengan
`sequence` 3. `flutter analyze` 0 issue; `flutter test` 649 lulus.
Berikutnya: uji perangkat fisik, pemindahan kunci indeks ke media offline,
dan domain kanonis `plugins.bufferite.dev`. Lihat `ROADMAP.md` dan
`progress.md` untuk detail.

## Referensi
- [CyberChef](https://github.com/gchq/CyberChef) — inspirasi utama untuk
  pendekatan recipe/operation dan kumpulan operasi yang menjadi acuan
  `core.berp`.
- [CyberChef Web](https://gchq.github.io/CyberChef/) — versi web untuk
  mencoba operasi secara langsung.
- Bufferite tidak berafiliasi dengan GCHQ atau proyek CyberChef.
