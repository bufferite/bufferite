# CONTRIBUTING.md — Bufferite

Terima kasih telah berkontribusi! Dokumen ini menjelaskan cara berkontribusi
pada inti aplikasi, core.berp, dan plugin komunitas.

## 1. Jenis Kontribusi
- Kode inti (engine, runtime, UI, plugin loader).
- Operasi core (isi core.berp).
- Plugin komunitas (.berp).
- Dokumentasi.
- Test dan audit keamanan.

## 2. Prinsip yang Wajib Dipegang
- Inti minimal: jangan menambah operasi hardcoded di inti. Operasi baru =
  plugin.
- Offline-first: jangan menambah akses jaringan tanpa izin eksplisit.
- Sandbox-first: plugin berjalan dengan batas resource.
- Transparansi: source plugin harus dapat dibaca dan direview.
- Versioned: perubahan kontrak Operation menaikkan versi.

## 3. Alur Kontribusi Kode Inti
1. Fork repo dan buat branch: feature/<nama> atau fix/<nama>.
2. Baca agent.md, architecture.md, dan plugins.md.
3. Tulis test untuk logika baru.
4. Pastikan linter dan test lulus.
5. Buat PR dengan deskripsi jelas: apa, mengapa, dan dampaknya.
6. Tunggu review maintainer.

## 4. Alur Kontribusi Operasi Core
1. Operasi core berada di core.berp (lihat operations.md).
2. Ikuti kontrak Operation: id stabil, parameter schema, contoh I/O, edge
   case.
3. Tambahkan test kontrak untuk operasi baru.
4. Perbarui operations.md.
5. Buat PR; operasi core akan direview untuk keamanan dan konsistensi.

## 5. Alur Kontribusi Plugin Komunitas
1. Buat plugin sesuai plugins.md.
2. Pilih tier: dsl, lua, atau wasm.
3. Sertakan plugin.manifest.json, entrypoint, README, LICENSE.
4. Bungkus sebagai .berp.
5. Uji sideload di aplikasi sebelum mengajukan ke registry.
6. Untuk registry resmi: ikuti `REGISTRY.md` (index + signature Ed25519
   wajib); ajukan PR ke repo registry dengan source (Lua) atau paket WASM +
   signature.
7. Review: keamanan, fungsionalitas, lisensi jelas, izin minimum, dan
   kepatuhan batas paket.

## 6. Gaya Kode
- Dart: flutter_lints + analysis_options.yaml.
- Penamaan: file snake_case, class PascalCase, variabel camelCase.
- Commit: Conventional Commits (feat, fix, docs, refactor, test, chore,
  security).
- Jangan menambah dependency tanpa alasan yang jelas di PR.

## 7. Keamanan
- Jangan menyertakan kredensial atau data sensitif di repo.
- Laporkan kerentanan secara privat ke maintainer (bukan issue publik).
- Plugin yang mencoba mengakses net/fs tanpa izin akan ditolak.

## 8. Lisensi
- Inti dan core.berp: MIT (rekomendasi).
- Plugin komunitas: mengikuti lisensi masing-masing; wajib dicantumkan di
  manifest dan file LICENSE.

## 9. Pertanyaan
Buka issue dengan label "question" atau hubungi maintainer.
