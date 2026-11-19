# roadmap.md — Bufferite Roadmap

Versi dokumen: 1.0
Status: Final (MVP)

## 1. Tujuan Roadmap
Memberi urutan kerja yang jelas dari MVP hingga potensi pengembangan,
dengan prioritas, risiko, dan definisi done per fase.

## 2. Ringkasan Fase
- Fase 0: Fondasi & bootstrap (inti + core.berp + runtime).
- Fase 1 (MVP): Recipe builder, core.berp lengkap, plugin manager,
  sideload, DSL + Lua + WASM berbarengan.
- Fase 2: Registry resmi, signature wajib, streaming file besar,
  peningkatan sandbox.
- Fase 3: Ekosistem lanjutan (marketplace, kolaborasi, AI assistant,
  multi-platform).

## 3. Fase 0 — Fondasi
Cakupan:
- Struktur proyek Flutter (feature-first).
- Recipe engine + pipeline executor.
- Kontrak Operation + Buffer model.
- Plugin loader + manifest parser + verifikasi SHA-256.
- Runtime DSL (engine sederhana).
- Runtime Lua native `lua_dart` (default) + engine WASM opt-in (wasmtime
  C API + lua_runtime.wasm, hash di-pin).
- Runtime plugin WASM (ABI command WASI v1).
- Storage (SQLite untuk recipe dan plugin).
- UI minimal: Home, Recipe Editor, Operation Picker.

Definisi done:
- Recipe sederhana (misal base64_decode) berjalan end-to-end dari plugin
  core.berp.
- Verifikasi hash runtime WASM dan paket .berp berfungsi.
- Test kontrak Operation lulus untuk satu operasi core.

## 4. Fase 1 — MVP
Cakupan:
- core.berp lengkap (hampir semua operasi CyberChef, lihat operations.md).
- Recipe management: simpan, muat, impor/ekspor .brecipe (JSON).
- Plugin Manager: daftar plugin, aktif/nonaktif, hapus, sideload .berp.
- Model izin + dialog peringatan (net, file).
- Sandbox: batas waktu, memori, tanpa net/fs kecuali izin.
- UI lengkap: Home, Recipe Editor (drag and drop, reorder, enable/disable,
  preview live), Operation Picker, Plugin Manager, Settings.
- Dark mode, empty state, error handling per step.
- Offline by default; katalog plugin opsional dengan peringatan.

Prioritas (MoSCoW):
- Must: recipe engine, core.berp, DSL + Lua + WASM, sideload, verifikasi
  hash, sandbox, UI inti.
- Should: impor/ekspor recipe, plugin manager lengkap, dark mode.
- Could: katalog plugin (registry read-only), pencarian operasi lanjutan.
- Won't (MVP): signature wajib, streaming file besar, marketplace.

Definisi done:
- Pengguna dapat membuat recipe multi-step dari operasi core.berp,
  menyimpannya, mengekspor, dan mengimpornya.
- Pengguna dapat menginstal plugin sideload .berp dan memakainya.
- Verifikasi hash menolak runtime/paket yang dimodifikasi.
- Semua operasi core.berp memiliki contoh I/O yang diuji.

## 5. Fase 2 — Pengerasan & Ekosistem Awal
Cakupan:
- Registry resmi (GitHub Pages/Repo) + UI katalog plugin
  (spesifikasi: `REGISTRY.md`).
- Signature wajib (Ed25519) untuk registry resmi.
- Streaming untuk file besar.
- Peningkatan sandbox (audit, fuzzing runtime).
- Plugin update/rollback.
- Log eksekusi plugin (opt-in) dan diagnostik.

Definisi done:
- Plugin dari registry dapat diinstal dengan verifikasi hash + signature.
- File besar diproses tanpa OOM.
- Audit keamanan runtime selesai; temuan ditangani.

## 6. Fase 3 — Ekosistem Lanjutan
Cakupan:
- Marketplace plugin (kurasi, rating, laporan).
- Kolaborasi recipe (berbagi, fork, komentar) — opt-in, privacy-aware.
- AI assistant opsional untuk menyusun recipe (lokal/remote, opt-in).
- Multi-platform (desktop/web) dengan Flutter.
- Integrasi share sheet dan automation.

Definisi done:
- Marketplace berjalan dengan moderasi aktif.
- Fitur kolaborasi tidak mengorbankan offline-first default.

## 7. Risiko Teknis & Mitigasi
1. Kompleksitas WASM di Flutter.
   Mitigasi: wasmtime C API + worker isolate; `lua_dart` tetap default.
2. Performa Lua untuk operasi berat.
   Mitigasi: engine Lua WASM opt-in + tier plugin WASM; benchmark sebelum
   dijadikan default.
3. Keamanan plugin komunitas.
   Mitigasi: sandbox ketat, review source (Lua), hash + signature Ed25519
   untuk registry resmi (`REGISTRY.md`).
4. Ukuran core.berp besar.
   Mitigasi: lazy load operasi, kompresi, pisah aset jika perlu.
5. Kontrak Operation berubah.
   Mitigasi: versioning kontrak + test kontrak terhadap core.berp.

## 8. Definisi Done Global
- Kode berjalan, test lulus, dokumen diperbarui.
- Tidak ada operasi hardcoded di inti.
- Verifikasi hash berfungsi untuk runtime dan paket.
- Tidak ada regresi pada recipe dan plugin.

## 9. Pertanyaan Terbuka
- Custody/rotasi kunci Ed25519 (D13) — lihat `REGISTRY.md` §12. Hosting/URL
  registry (D12) sudah selesai.
- Target rilis MVP sudah ditetapkan dan tercapai: 2026-12-31 (D07).
