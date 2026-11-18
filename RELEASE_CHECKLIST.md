# Release Checklist MVP (F15-T06)

Verifikasi `AGENT.md` §7 dan `ROADMAP.md` Fase 1 sebelum tag rilis.

| Item | Status | Bukti |
|---|---|---|
| Target rilis | 2026-12-31 | D07 (fallback 1.0 DSL-only bila runtime tertahan) |
| Dokumen acuan diperbarui | OK | `operations.md`, `ARCHITECTURE.md`, `PLUGINS.md`, `THREAT_MODEL.md`, `PRIVACY.md`, `CHANGELOG.md` |
| Struktur folder & penamaan | OK | feature-first `lib/core`, `lib/features`, `lib/core/operations` |
| Tidak ada operasi di-hardcode di inti | OK | operasi = plugin (`lib/core/operations` = paket core) |
| Unit test logika baru + lulus | OK | `flutter test` → 400 lulus |
| Test kontrak terhadap core.berp | SEBAGIAN | `test/tool/*` build+decode; runner nyata menunggu F05-T04 |
| Tanpa dependency baru tanpa alasan | OK | dicatat di `ARCHITECTURE.md` §12 |
| Operasi berat di isolate | BELUM | F03-T04 ditunda |
| Verifikasi SHA-256 runtime WASM & .berp | SEBAGIAN | `.berp` OK (`plugin_integrity_test`); aset WASM dipin (`lua_runtime_asset_test`); eksekusi menunggu F05-T04 |
| UI layar kecil/besar + dark mode | SEBAGIAN | widget test + smoke emulator (dark); layar besar manual |
| Skema recipe versioned | OK | `schemaVersion` + migrasi berantai |
| Conventional Commits | OK | riwayat commit `feat:`, `fix:`, `docs:`, `test:`, `chore:` |
| Ringkasan perubahan untuk manusia | OK | `progress.md` + `CHANGELOG.md` |

## Ringkasan Fase 1 (ROADMAP)

Tercapai: engine + recipe + pipeline, sistem plugin (manifest/paket/izin),
storage, UI foundation, Home, Recipe Editor, Library, Plugin Manager, Settings,
core.berp tooling + operasi inti, keamanan dasar.

Tertunda (dicatat): instansiasi runtime Lua/WASM (F05-T04), host isolate
(F03-T04), enforcement izin runtime, katalog daring Fase 2, sebagian verifikasi
device.

Kesimpulan: MVP memenuhi Definisi Done untuk lingkup non-device; item tertunda
dilacak di `progress.md` §8 Blocker.