# Release Checklist MVP (F15-T06)

Verifikasi `AGENT.md` §7 dan `ROADMAP.md` Fase 1 sebelum tag rilis.

| Item | Status | Bukti |
|---|---|---|
| Target rilis | 2026-12-31 | D07 (fallback 1.0 DSL-only bila runtime tertahan) |
| Dokumen acuan diperbarui | OK | `operations.md`, `ARCHITECTURE.md`, `PLUGINS.md`, `THREAT_MODEL.md`, `PRIVACY.md`, `CHANGELOG.md` |
| Struktur folder & penamaan | OK | feature-first `lib/core`, `lib/features`, `lib/core/operations` |
| Tidak ada operasi di-hardcode di inti | OK | operasi = plugin (`lib/core/operations` = paket core) |
| Unit test logika baru + lulus | OK | `flutter test` → 512 lulus (2026-11-19) |
| Test kontrak terhadap core.berp | OK | build+decode `test/tool/*`; operasi core dieksekusi via executor |
| Tanpa dependency baru tanpa alasan | OK | dicatat di `ARCHITECTURE.md` §12 |
| Operasi berat di isolate | OK | pipeline + Lua/Lua WASM/plugin WASM di worker isolate (CP-054/CP-063/CP-065) |
| Verifikasi SHA-256 runtime WASM & .berp | OK | `.berp` (`plugin_integrity_test`); aset WASM dipin (`lua_runtime_asset_test`); eksekusi device (CP-063/CP-065) |
| Matriks izin & bypass lintas runtime | OK | `permission_matrix_test.dart` 32 test; tier `wasm` fs/import diblokir (CP-065) |
| Build release + smoke install | OK | universal 53,1 MB; split `arm64-v8a` 18,5 MB / `armeabi-v7a` 16,0 MB / `x86_64` 19,9 MB; install + launch x86_64 OK; tanpa `libwasmtime` (sesuai 1.0) |
| UI layar kecil/besar + dark mode | SEBAGIAN | widget test + smoke emulator (dark); layar besar manual |
| Skema recipe versioned | OK | `schemaVersion` + migrasi berantai |
| Conventional Commits | OK | riwayat commit `feat:`, `fix:`, `docs:`, `test:`, `chore:` |
| Ringkasan perubahan untuk manusia | OK | `progress.md` + `CHANGELOG.md` |

## Ringkasan Fase 1 (ROADMAP)

Tercapai: engine + recipe + pipeline, sistem plugin (manifest/paket/izin),
storage, UI foundation, Home, Recipe Editor, Library, Plugin Manager, Settings,
core.berp tooling + operasi inti, keamanan dasar.

Tertunda (dicatat): katalog daring Fase 2; pengemasan libwasmtime di build
release Android (tier `wasm`/`LuaEngine.wasm` baru aktif di build yang memuat
engine); verifikasi perangkat arm64 fisik. Semua task MVP (131/131) selesai
per CP-065.

Artefak rilis: `app-release.apk` (universal) atau
`app-<abi>-release.apk` dari `flutter build apk --release --split-per-abi`.
Keduanya tidak memuat `libwasmtime`; tier `wasm` memerlukan build khusus yang
menyertakan library engine.

Kesimpulan: MVP memenuhi Definisi Done untuk lingkup 1.0; item tertunda
dilacak di `progress.md` §8 Blocker.

## Checklist Publikasi Registry (D12/D13/D14)

| Item | Status | Bukti |
|---|---|---|
| Model distribusi tanpa marketplace lanjutan | OK | D14: PR ke `bufferite/plugins`, CI verify, review, merge; app hanya search/detail/install |
| Trust anchor produksi dibundel | OK | `assets/registry_keys.json` + `test/core/registry/registry_trust_store_asset_test.dart` (`7df70b3`) |
| Kunci indeks offline, kunci paket secret CI | SEBAGIAN | Kunci paket sudah menjadi secret `REGISTRY_PACKAGE_KEY`; kunci indeks dipakai menandatangani rilis dan masih berada di `G:\Code\Flutter\.keys\index.json` (di luar repo) — wajib segera dipindah ke media offline |
| Rehearsal lokal rilis penuh | OK | paket 1.0.0/1.1.0: signature, build indeks, sequence 1→2→3, rebuild deterministik, immutability, tamper/replay ditolak; artifact CI `sequence` 3 identik dengan rehearsal |
| Repo `bufferite/plugins` | OK | Scaffold D13/D14 di-push ke `main`; rilis live terakhir `c37b6f1` (`sequence` 3) |
| GitHub Pages + DNS | OK (sementara) | Pages via Actions aktif tanpa custom domain; site `https://bufferite.github.io/plugins/` (D15). Domain `plugins.bufferite.dev` menunggu registrasi, lalu CNAME `plugins` → `bufferite.github.io` |
| Environment `registry-publish` + secret | OK | Required reviewer `exphert`; secret `REGISTRY_PACKAGE_KEY` terpasang; tidak ada secret kunci indeks |
| `BUFFERITE_TOOL_REF` | OK | `a4ba47d` (commit aplikasi yang sudah di-push dan memuat `tool/registry_cli.dart`) |
| Release ditandatangani | OK | Plugin `dev.bufferite.newline-normalizer` `1.1.0`: `publish.yml` run `44765363101` → signing offline `.keys/index.json` → `release/registry.json` + `.sig` (`c37b6f1`) → `deploy.yml` run `44767289603`. Live: `sequence` 3, sha256 `1b9f22e3d9df365347256e3499c741efdcdc68e773876f7c60d83a0b3dd37440`, signature verified |
| Smoke test client aplikasi | OK | `RegistryClient.loadWithFallback()` terhadap `https://bufferite.github.io/plugins/registry/v1/registry.json`: signature valid, `sequence` naik ke 3, `allowedHosts=[bufferite.github.io]`, cache terverifikasi |
| Uji katalog di emulator | OK | Android 12: katalog `sequence` 2 → install `1.0.0` → update ke `1.1.0` → `1.0.0` tampil `revoked`; signature indeks+paket valid; plugin `1.1.0` aktif, operasi muncul di Library, input CRLF menghasilkan output tiga baris LF |
| Uji katalog di perangkat | DITUNDA | Uji perangkat Android fisik ditunda; tidak memblokir publikasi |

Catatan: jangan menaruh `REGISTRY_INDEX_KEY` di CI. Signing indeks selalu
dilakukan di mesin offline; lihat `registry-scaffold/release/README.md`.
Catatan: Pages meng-cache `registry.json` selama 10 menit (`max-age=600`).
Jika publish berikutnya dijalankan kurang dari 10 menit setelah deploy,
tunggu cache kedaluwarsa atau jalankan ulang `workflow_dispatch` agar workflow
membaca indeks lama yang benar; `sequence` harus selalu naik.
Catatan: `deploy.yml` menandatangani paket dengan kunci package CI sebelum
rebuild deterministik. Menjalankan ulang deploy untuk `release/` yang
`sequence`-nya sudah live akan gagal di rebuild (replay guard), jadi perubahan
workflow saja tidak bisa diuji dengan men-deploy ulang indeks lama.