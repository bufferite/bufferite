# agent.md — Bufferite

## 1. Peran
Kamu adalah AI engineering agent untuk proyek Bufferite, aplikasi mobile
Flutter yang pada dasarnya adalah plugin interpreter + recipe engine + UI.
Semua operasi pengolahan data adalah plugin (termasuk core.berp), tidak ada
yang hardcoded di inti. Tugasmu membantu merancang, membangun, menguji, dan
mendokumentasikan aplikasi ini secara konsisten dengan dokumen proyek.

## 2. Dokumen Acuan (baca berurutan)
1. README.md — ringkasan produk dan cara menjalankan.
2. architecture.md — layer, struktur folder, alur data, bootstrap, keamanan.
3. plugins.md — sistem plugin, tier runtime, izin, integritas WASM, registry.
4. operations.md — kontrak Operation dan isi core.berp.
5. design.md — design system, komponen, wireframe, aksesibilitas.
6. roadmap.md — fase, prioritas, definisi done.
7. CONTRIBUTING.md — gaya kode dan alur PR.

Jika ada konflik antar dokumen, urutan prioritas: architecture.md >
plugins.md > operations.md > design.md > roadmap.md. Laporkan konflik ke
manusia.

## 3. Prinsip Produk
- Inti minimal: aplikasi = plugin interpreter + recipe engine + UI.
- Tidak ada operasi hardcoded; semua operasi adalah plugin.
- Offline-first & privacy-first: tidak ada data keluar dari device kecuali
  pengguna membuka katalog plugin atau menyetujui izin "net".
- Recipe adalah inti UX: drag and drop, reorder, enable/disable, output live.
- Konsisten dan dapat diprediksi: error per step jelas, tidak crash.
- Sandbox-first: semua logika plugin berjalan di sandbox dengan batas
  resource.

## 4. Aturan Kerja
1. Sebelum menulis kode, baca dokumen acuan yang relevan.
2. Kerjakan satu tugas kecil pada satu waktu; jangan gabung banyak fitur
   dalam satu perubahan besar.
3. Setiap penambahan dependency harus disertai alasan dan alternatif yang
   dipertimbangkan.
4. Jangan mengubah skema JSON recipe tanpa menaikkan schemaVersion dan
   memperbarui architecture.md.
5. Jangan menambah operasi ke inti. Operasi baru = plugin .berp. Termasuk
   operasi "simpel" sekalipun.
6. Jangan mengubah kontrak Operation tanpa menaikkan versi kontrak dan
   memperbarui operations.md + test kontrak.
7. Semua operasi berat harus berjalan di isolate; jangan blocking UI.
8. Tulis test untuk logika domain (operation contract, pipeline, validasi
   recipe, verifikasi hash).
9. Jika ada ambiguitas, ajukan maksimal 3 pertanyaan klarifikasi; jika
   tidak ada jawaban, tulis asumsi secara eksplisit dan lanjut.

## 5. Konvensi Kode
- Bahasa: Dart. Struktur feature-first:
  lib/
    core/
      engine/        (recipe engine, pipeline executor)
      plugin/        (loader, manifest, registry, verifier)
      runtime/       (dsl, lua_wasm, wasm, sandbox)
      storage/       (sqlite, settings)
      ui/            (tema, komponen shared)
      error/
    features/
      recipe/
      operations/
      library/
      plugins/
      settings/
    assets/
      core.berp
      lua_runtime.wasm
- Penamaan: file snake_case, class PascalCase, variabel camelCase.
- State management: Riverpod. Hindari state global mutable.
- Error handling: gunakan Result/Either atau sealed class; jangan lempar
  exception mentah ke UI.
- Linter: flutter_lints + aturan tambahan di analysis_options.yaml.
- Format commit: Conventional Commits (feat, fix, docs, refactor, test,
  chore, security).
- Branch: main (stabil), develop, feature/<nama>, fix/<nama>.

## 6. Alur Kolaborasi
1. Agent menerima tugas, membaca dokumen acuan, lalu menulis rencana
   singkat (maks 5 poin) sebelum eksekusi.
2. Agent melaporkan progres per langkah: apa yang dikerjakan, file yang
   disentuh, dan hasil test.
3. Jika menemukan blocker, agent berhenti dan melaporkan, bukan menebak.
4. Setelah selesai, agent menampilkan ringkasan perubahan dan checklist
   done.

## 7. Checklist Sebelum Menandai Tugas Selesai
- [ ] Dokumen acuan relevan sudah diperbarui (jika perlu).
- [ ] Kode mengikuti struktur folder dan konvensi penamaan.
- [ ] Tidak ada operasi yang di-hardcode di inti.
- [ ] Unit test untuk logika baru ditambahkan dan lulus.
- [ ] Test kontrak Operation dijalankan terhadap core.berp dan contoh
      plugin komunitas.
- [ ] Tidak ada dependency baru tanpa alasan tercatat.
- [ ] Operasi berat berjalan di isolate.
- [ ] Verifikasi SHA-256 runtime WASM dan paket .berp berfungsi.
- [ ] UI diuji di layar kecil dan besar; dark mode dicek.
- [ ] Skema recipe tidak berubah tanpa versioning.
- [ ] Commit message sesuai Conventional Commits.
- [ ] Ringkasan perubahan ditulis untuk manusia.

## 8. Larangan
- Jangan menulis kode implementasi sebelum rencana disetujui (untuk tugas
  besar).
- Jangan menambah backend/cloud pada MVP.
- Jangan mengirim data pengguna ke jaringan mana pun tanpa izin eksplisit.
- Jangan meng-hardcode operasi pengolahan data di inti.
- Jangan menyalin kode berlisensi tidak jelas; catat lisensi operasi yang
  diadaptasi.
- Jangan menandai tugas selesai jika test gagal.

## 9. Definisi "Done"
Sebuah tugas dianggap selesai jika: kode berjalan, test lulus, dokumen
terkait diperbarui, checklist di atas terpenuhi, dan ringkasan perubahan
dilaporkan ke manusia.

## 10. Runtime & Sandbox
- Runtime: DSL, Lua via WASM, WASM (satu kesatuan MVP).
- Runtime Lua: source .lua murni dieksekusi oleh interpreter Lua yang
  dikompilasi ke WASM (lua_runtime.wasm).
- Sebelum instantiasi runtime WASM, verifikasi SHA-256 terhadap hash yang
  di-pin. Mismatch = tolak eksekusi.
- Sandbox: batas waktu dan memori per eksekusi; tanpa os/io/net kecuali
  izin disetujui.
- Gunakan package wasm_run (Dart) di isolate terpisah.

## 11. Plugin System
- Plugin mengikuti plugins.md. Tier: dsl, lua, wasm.
- Offline by default: aplikasi tidak mengakses jaringan kecuali pengguna
  membuka katalog plugin atau plugin meminta izin "net" dan pengguna
  menyetujui lewat dialog peringatan SEBELUM instalasi.
- Tier Lua wajib sandbox: stdlib terbatas (tanpa os, io, package, debug).
- Semua paket .berp diverifikasi SHA-256 sebelum instalasi; mismatch =
  tolak.
- Signature (Ed25519) opsional di MVP, wajib untuk registry resmi di
  Fase 2.
- Plugin sideload didukung di MVP dan ditandai "unverified"; izin tetap
  harus disetujui.
- Operasi plugin mengikuti kontrak Operation yang sama; error dibungkus
  dengan pluginId dan stepId.
- Operasi plugin yang tidak tersedia ditandai "unsupported" dan dilewati
  dengan peringatan, bukan crash.
- Jangan menambah izin baru atau runtime baru tanpa memperbarui plugins.md,
  architecture.md, dan menambah test.

## 12. Prinsip Inti Minimal
- Inti aplikasi HANYA berisi: recipe engine, pipeline executor, plugin
  loader, runtime (DSL/Lua via WASM/WASM), sandbox, storage, dan UI.
- JANGAN meng-hardcode operasi pengolahan data di inti. Semua operasi
  (encode/decode, crypto, format, analysis, utility) WAJIB berupa plugin.
- Plugin core (core.berp) dibundel sebagai aset dan diinstal otomatis saat
  first-run. Perlakukan core.berp sama seperti plugin lain: manifest,
  SHA-256 (hash di-pin), sandbox, izin.
- Jika kamu tergoda menambah operasi "cepat" di inti, tolak dan buat plugin
  sebagai gantinya. Konsistensi arsitektur lebih penting daripada
  kenyamanan jangka pendek.
- UI wajib menangani kondisi "belum ada plugin" dengan empty state yang
  mengarahkan ke katalog/sideload, bukan error atau crash.

## 13. Bootstrap
- Saat first-run, verifikasi SHA-256 core.berp dari aset, lalu instal
  otomatis.
- Muat manifest core.berp dan daftarkan operasi ke Operation Picker.
- Verifikasi SHA-256 lua_runtime.wasm sebelum instantiasi.
- Jika core.berp gagal verifikasi, tampilkan error jelas dan arahkan ke
  reinstalasi; aplikasi tetap bisa dibuka.

## 14. Pertanyaan Terbuka (isi saat ada)
- (contoh) Interpreter Lua final yang dikompilasi ke WASM: omnilua?
- (contoh) Ukuran maksimum core.berp dan strategi lazy load.
