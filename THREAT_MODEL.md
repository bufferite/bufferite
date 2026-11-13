# Bufferite — Threat Model (F14-T01)

Versi: 1.0 · Fase: MVP

## 1. Aset yang dilindungi

1. Data pengguna (buffer, file yang dipilih, hasil operasi).
2. Recipe tersimpan (`.brecipe`, SQLite).
3. Plugin terpasang + izin yang diberikan.
4. Integritas runtime (`core.berp`, `lua_runtime.wasm`).
5. Privasi: tidak ada eksfiltrasi data tanpa aksi pengguna.

## 2. Aktor

- **Pengguna** — pemilik perangkat.
- **Plugin jahat** — paket `.berp` dari sideload/katalog yang mencoba keluar
  sandbox.
- **Penyerang jaringan** — hanya relevan bila fitur katalog Fase 2 aktif.
- **Penyerang lokal / aplikasi lain** — mencoba membaca data aplikasi atau
  menukar paket.

## 3. Jalur serang dan mitigasi

| # | Jalur serang | Mitigasi |
|---|---|---|
| 1 | Zip-slip / path traversal di `.berp` | Validasi path relatif, tolak `..`, absolut, separator Windows |
| 2 | Zip bomb / entri raksasa | Batas 32 MiB paket, 512 entri, 16 MiB/entri, 64 MiB total |
| 3 | Symlink/duplikat entri | Tolak symlink; tolak duplikat case-insensitive |
| 4 | Paket/runner dimodifikasi | SHA-256 dipin; mismatch = tolak eksekusi |
| 5 | Akses net/fs tanpa izin | `PermissionGuard` + dialog izin; runtime tanpa `os`/`io` |
| 6 | ReDoS dari regex | Batas panjang pola + timeout eksekusi |
| 7 | Kehabisan resource | Batas waktu 2 dtk/operasi, memori 64 MiB |
| 8 | Acak tidak aman | CSPRNG (`Random.secure`) untuk operasi acak |
| 9 | Jalur jaringan implisit | Offline-by-default; jaringan hanya untuk katalog (Fase 2) |
| 10 | Data rusak di storage | Error storage terstruktur; fallback default settings |

## 4. Asumsi & batasan MVP

- Eksekusi masih di isolate pemanggil; host isolate + kill paksa (F03-T04)
  belum ada, sehingga timeout hanya best-effort.
- Enforcement izin runtime Lua/WASM menunggu F05-T03/T04.
- Perlindungan data mengandalkan sandbox OS (Android/iOS/desktop).

## 5. Status verifikasi

- Suspected: `test/core/plugin_package_test.dart`,
  `test/core/plugin_integrity_test.dart`, `test/core/plugin_permission_test.dart`.
- Terbuka: test bypass izin runtime (F14-T03), keamanan regex terukur
  (F14-T04), CSPRNG operasi acak (F14-T05), audit offline (F14-T06).
