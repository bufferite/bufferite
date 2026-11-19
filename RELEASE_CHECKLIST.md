# Release Checklist MVP (F15-T06)

Verifikasi `AGENT.md` §7 dan `ROADMAP.md` Fase 1 sebelum tag rilis.

| Item | Status | Bukti |
|---|---|---|
| Target rilis | 2026-12-31 | D07 (fallback 1.0 DSL-only bila runtime tertahan) |
| Dokumen acuan diperbarui | OK | `operations.md`, `ARCHITECTURE.md`, `PLUGINS.md`, `THREAT_MODEL.md`, `PRIVACY.md`, `CHANGELOG.md` |
| Struktur folder & penamaan | OK | feature-first `lib/core`, `lib/features`, `lib/core/operations` |
| Tidak ada operasi di-hardcode di inti | OK | operasi = plugin (`lib/core/operations` = paket core) |
| Unit test logika baru + lulus | OK | `flutter test` → 454 lulus |
| Test kontrak terhadap core.berp | OK | build+decode `test/tool/*`; operasi core dieksekusi via executor |
| Tanpa dependency baru tanpa alasan | OK | dicatat di `ARCHITECTURE.md` §12 |
| Operasi berat di isolate | OK | pipeline + Lua/Lua WASM di isolate kerja (CP-054/CP-063) |
| Verifikasi SHA-256 runtime WASM & .berp | OK | `.berp` (`plugin_integrity_test`); aset WASM dipin (`lua_runtime_asset_test`); eksekusi device (CP-063) |
| UI layar kecil/besar + dark mode | SEBAGIAN | widget test + smoke emulator (dark); layar besar manual |
| Skema recipe versioned | OK | `schemaVersion` + migrasi berantai |
| Conventional Commits | OK | riwayat commit `feat:`, `fix:`, `docs:`, `test:`, `chore:` |
| Ringkasan perubahan untuk manusia | OK | `progress.md` + `CHANGELOG.md` |

## Ringkasan Fase 1 (ROADMAP)

Tercapai: engine + recipe + pipeline, sistem plugin (manifest/paket/izin),
storage, UI foundation, Home, Recipe Editor, Library, Plugin Manager, Settings,
core.berp tooling + operasi inti, keamanan dasar.

Tertunda (dicatat): ABI plugin tier WASM (F05-T06; engine sudah ada),
matriks izin runtime (F14-T03), katalog daring Fase 2, sebagian verifikasi
device — ditunda ke 1.1 sesuai D07.

Kesimpulan: MVP memenuhi Definisi Done untuk lingkup non-device; item tertunda
dilacak di `progress.md` §8 Blocker.