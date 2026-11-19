# registry.md — Spesifikasi Registry Plugin Bufferite

Versi dokumen: 1.0 (draf)
Status: **Belum diimplementasikan** — acuan F16-T01..T04 dan F16-T08
Berlaku untuk: registry resmi read-only Bufferite
Dokumen terkait: [PLUGINS.md](PLUGINS.md), [THREAT_MODEL.md](THREAT_MODEL.md),
[PRIVACY.md](PRIVACY.md)

## 1. Status & Ruang Lingkup

Registry adalah katalog plugin `.berp` yang dapat dilihat dan diinstal dari
dalam aplikasi. Registry resmi bersifat **read-only**, **statis**, dan
**opsional**: aplikasi tetap berjalan penuh secara offline tanpa registry.

Ruang lingkup v1:

- Satu registry resmi (tidak ada registry pihak ketiga yang dapat ditambah
  pengguna pada v1).
- Indeks `registry.json` + signature Ed25519 terpisah.
- Paket `.berp` + signature Ed25519 terpisah.
- Instalasi, update, rollback, dan notifikasi revocation.
- Cache indeks lokal dan perilaku offline.

Di luar ruang lingkup v1:

- Rating, komentar, marketplace, dan akun pengguna (F17).
- Auto-update di latar belakang.
- Registri pihak ketiga / URL kustom dari pengguna.
- Ikon atau aset gambar dari jaringan (dapat ditambahkan nanti).
- Hosting dan URL publik (keputusan D12, lihat §12).

## 2. Prinsip & Model Kepercayaan

1. **Offline-first.** Tidak ada request jaringan saat aplikasi dibuka,
   kecuali pengguna membuka katalog atau menekan "Perbarui katalog".
2. **Eksplisit.** Pengguna melihat peringatan jaringan sebelum request
   pertama dan dapat mencabut konsen di Settings.
3. **Read-only.** Aplikasi hanya melakukan `GET`; tidak ada unggahan data,
   cookie, autentikasi, atau telemetri.
4. **Integritas berlapis.** Hash SHA-256 membuktikan byte tidak berubah;
   signature Ed25519 membuktikan asal paket. Keduanya wajib untuk registry
   resmi.
5. **Trust anchor di aplikasi.** Public key Ed25519 di-pin di aplikasi,
   bukan diambil dari registry. Registry yang dikompromikan tidak dapat
   mengganti kunci sendiri.
6. **Metadata ikut diautentikasi.** Signature indeks melindungi seluruh
   `registry.json`, termasuk `pluginId`, versi, izin, hash, dan URL unduhan.
7. **Sideload tetap hash-only.** Plugin sideload ditandai `unverified` dan
   tidak pernah dianggap setara dengan plugin registry.
8. **Tidak ada instalasi diam-diam.** Setiap instalasi/update memerlukan
   aksi pengguna; izin baru selalu meminta persetujuan ulang.

## 3. Hosting & Tata Letak File

Hosting belum diputuskan (D12). Persyaratan minimum:

- HTTPS dengan sertifikat valid; tidak ada HTTP atau cleartext.
- File statis, read-only, dan dapat di-cache CDN.
- URL paket **immutable**: satu URL hanya untuk satu versi paket.
- `Content-Type: application/json` untuk indeks dan signature;
  `application/octet-stream` untuk `.berp`.

Tata letak yang direkomendasikan:

```text
/registry/v1/registry.json
/registry/v1/registry.json.sig
/registry/v1/packages/<pluginId>/<version>/<nama-paket>.berp
/registry/v1/packages/<pluginId>/<version>/<nama-paket>.berp.sig
```

`downloadUrl` boleh absolut atau relatif terhadap URL `registry.json`.
URL final wajib HTTPS dan host-nya harus termasuk `allowedHosts` yang
ditandatangani di indeks. Redirect maksimum 3, semuanya wajib HTTPS.

## 4. Format `registry.json` v1

Contoh:

```json
{
  "registryVersion": 1,
  "sequence": 12,
  "generatedAt": "2026-11-19T00:00:00Z",
  "allowedHosts": ["registry.contoh.dev", "cdn.contoh.dev"],
  "plugins": [
    {
      "pluginId": "com.contoh.encoding-pack",
      "version": "1.2.0",
      "name": "Encoding Pack",
      "summary": "Kumpulan operasi encoding tambahan.",
      "description": "Deskripsi panjang dalam teks biasa.",
      "author": "nama/komunitas",
      "license": "MIT",
      "homepage": "https://contoh.dev/encoding-pack",
      "tier": "lua",
      "minAppVersion": "1.0.0",
      "permissions": ["cpu"],
      "sizeBytes": 12345,
      "sha256": "0123abcd...",
      "downloadUrl": "packages/com.contoh.encoding-pack/1.2.0/encoding-pack-1.2.0.berp",
      "signatureUrl": "packages/com.contoh.encoding-pack/1.2.0/encoding-pack-1.2.0.berp.sig",
      "publishedAt": "2026-11-18T10:00:00Z",
      "status": "active",
      "tags": ["encoding"]
    }
  ]
}
```

### 4.1 Field wajib

| Field | Tipe | Aturan |
|---|---|---|
| `registryVersion` | int | Wajib `1`; versi lain ditolak dengan pesan update aplikasi |
| `sequence` | int | Positif dan monoton naik; dipakai menolak replay indeks lama |
| `generatedAt` | string | ISO-8601 UTC |
| `allowedHosts` | array string | 1–8 hostname tanpa skema/path |
| `plugins` | array | 0–2.000 rilis |

Setiap entri `plugins` wajib memiliki:

| Field | Tipe | Aturan |
|---|---|---|
| `pluginId` | string | Reverse-DNS, sama dengan manifest: `^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9_-]*)+$` |
| `version` | string | Semver, sama dengan manifest |
| `name` | string | 1–80 karakter, teks biasa |
| `summary` | string | 1–200 karakter, teks biasa |
| `tier` | string | `dsl`, `lua`, atau `wasm` |
| `minAppVersion` | string | Semver |
| `permissions` | array | Subset `cpu`, `net`, `file:read`, `file:write`; tanpa duplikat |
| `sizeBytes` | int | 1..33.554.432 (32 MiB) |
| `sha256` | string | Hex lowercase 64 karakter dari file `.berp` |
| `downloadUrl` | string | Absolut/relatif, HTTPS setelah resolusi, ≤ 2.048 karakter |
| `publishedAt` | string | ISO-8601 UTC |
| `status` | string | `active`, `deprecated`, `yanked`, atau `revoked` |

Field opsional: `description` (≤ 4.000 karakter), `author` (≤ 120),
`license` (≤ 64), `homepage` (≤ 512), `signatureUrl` (default
`downloadUrl + ".sig"`), `tags` (≤ 8 item, masing-masing ≤ 32 karakter).

### 4.2 Aturan parsing

- Satu entri = satu rilis. Plugin dengan beberapa versi muncul sebagai
  beberapa entri; klien mengelompokkan berdasarkan `pluginId`.
- Field yang tidak dikenal diabaikan (kompatibilitas maju).
- Field wajib yang hilang, tipe salah, atau melewati batas → seluruh indeks
  ditolak (fail closed), bukan dilewati per entri.
- Versi yang lebih tinggi dari `registryVersion` yang didukung → tampilkan
  "Perbarui aplikasi untuk membuka katalog ini".
- `sequence` lebih kecil dari cache terakhir → tolak sebagai replay dan
  pertahankan cache lama.
- Ukuran `registry.json` maksimum **5 MiB**; signature maksimum **4 KiB**.

## 5. Signature & Kunci Ed25519

### 5.1 File signature

Signature bersifat detached, satu file per objek:

```json
{
  "algorithm": "ed25519",
  "keyId": "official-index-2026-01",
  "signature": "<base64 64 byte>"
}
```

- `registry.json.sig` untuk indeks.
- `<nama-paket>.berp.sig` untuk paket.
- Signature file tidak ditandatangani; validitasnya bergantung pada
  verifikasi kunci yang di-pin. `keyId` yang tidak dikenal atau dicabut
  selalu ditolak.

### 5.2 Pesan yang ditandatangani

Gunakan domain separation agar signature indeks tidak dapat dipakai ulang
untuk paket:

```text
Indeks:
bufferite-registry-v1:index\n<sha256-hex>\n<sizeBytes>

Paket:
bufferite-registry-v1:package\n<pluginId>\n<version>\n<sha256-hex>\n<sizeBytes>
```

`sha256-hex` adalah hash byte mentah file (lowercase), `sizeBytes` adalah
jumlah byte file dalam desimal. Signature Ed25519 dibuat atas byte UTF-8 dari
pesan tersebut.

### 5.3 Trust store

Public key di-pin di aplikasi (rencana: `assets/registry_keys.json`):

```json
{
  "keys": [
    {
      "keyId": "official-index-2026-01",
      "algorithm": "ed25519",
      "usage": "index",
      "publicKey": "<base64 32 byte>",
      "status": "active",
      "createdAt": "2026-11-19"
    }
  ]
}
```

- `usage`: `index`, `package`, atau `both`.
- `status`: `active` atau `revoked`. Kunci `revoked` selalu ditolak.
- Menambah atau mencabut kunci memerlukan rilis aplikasi baru. Ini adalah
  kompromi sadar: tidak ada remote key update.
- Rotasi: publikasikan kunci baru di aplikasi, tanda tangani ulang indeks
  dan paket, pertahankan kunci lama minimal 90 hari, lalu cabut lewat rilis
  aplikasi berikutnya.
- Rekomendasi: kunci indeks disimpan offline (air-gapped/HSM); kunci paket
  boleh berbeda dan dipakai CI. Keduanya di-pin.

### 5.4 Urutan verifikasi

1. Unduh `registry.json` dan `registry.json.sig`.
2. Hitung SHA-256 dan ukuran byte indeks.
3. Verifikasi signature indeks dengan kunci `usage` yang sesuai.
4. Parse dan validasi skema.
5. Periksa `sequence` terhadap cache.
6. Simpan cache hanya setelah semua langkah lulus.

Untuk paket, verifikasi dilakukan **sebelum** paket dibuka/diekstrak:

1. Unduh ke file sementara sambil menghitung SHA-256 dan ukuran.
2. Cocokkan dengan `sha256`/`sizeBytes` entri.
3. Verifikasi signature paket dengan `pluginId`/`version` dari entri.
4. Baru buka `.berp` dengan pembatas paket yang sudah ada.

## 6. Jaringan, Konsen, dan Cache

- **Pemicu:** pengguna membuka tab katalog, menekan "Perbarui", atau memilih
  instalasi. Tidak ada sinkronisasi latar belakang.
- **Konsen pertama:** dialog menjelaskan bahwa aplikasi akan mengakses
  internet, hanya mengunduh katalog dan paket yang dipilih, dan tidak
  mengirim buffer/recipe. Konsen disimpan di Settings dan dapat dicabut.
- **Header:** `User-Agent: Bufferite/<versi>`, `Accept: application/json`
  untuk indeks. Tanpa cookie, token, atau parameter identitas.
- **Batas:** timeout koneksi 10 detik; total indeks 30 detik; paket 2 menit;
  ukuran mengikuti §4.2 dan batas `.berp` 32 MiB.
- **Redirect:** maksimal 3, wajib HTTPS, host final harus ada di
  `allowedHosts`.
- **Cache indeks:** disimpan lokal bersama signature dan `fetchedAt`.
  TTL tampilan 24 jam. Jika kedaluwarsa, tampilkan cache + tombol perbarui;
  jika refresh gagal, tetap tampilkan cache dengan banner offline.
- **Verifikasi cache:** signature diverifikasi ulang setiap kali cache
  dimuat, bukan hanya saat unduhan pertama.
- **Hapus cache:** tersedia di Settings; tidak menghapus plugin terpasang.
- **Izin platform:** `INTERNET` baru ditambahkan saat fitur ini dirilis.
  Rilis 1.0 tidak memintanya (lihat `PRIVACY.md`).

## 7. Alur Instalasi

1. Muat/refresh indeks dan verifikasi signature (§5.4).
2. Pilih entri; tampilkan nama, versi, tier, ukuran, sumber, status
   verifikasi, dan izin.
3. Tolak jika `minAppVersion` lebih tinggi dari versi aplikasi.
4. Jika izin selain `cpu` atau ada izin baru dibanding versi terpasang,
   tampilkan dialog eksplisit. Tanpa persetujuan → batal.
5. Unduh paket + signature ke penyimpanan sementara; verifikasi hash,
   ukuran, dan signature.
6. Buka `.berp` dengan pembatas paket yang ada (`PLUGINS.md` §6).
7. Cocokkan manifest dengan entri: `pluginId`, `version`, `tier`, dan set
   izin harus sama. Mismatch → tolak.
8. Instal atomik lewat `PluginPackageStore`, aktifkan, lalu daftarkan
   operasi ke registry.
9. Simpan provenance: `source=registry`, `registryUrl`, `keyId`, `sha256`,
   `installedAt`, dan `previousVersion` bila ada.

Jika langkah 8 gagal, versi lama (jika ada) tetap aktif dan file sementara
dibersihkan.

## 8. Update, Rollback, dan Provenance

- **Cek update:** bandingkan versi terpasang dengan rilis `active` tertinggi
  yang memenuhi `minAppVersion`. Tampilkan badge di Plugin Manager dan
  katalog; tanpa notifikasi push.
- **Update:** ikuti alur instalasi §7. Jika set izin bertambah, minta
  persetujuan ulang; jika berkurang, tidak perlu dialog. Status
  enable/disable dipertahankan.
- **Retensi:** simpan maksimal dua versi per plugin (aktif + sebelumnya).
  Versi lebih lama dibersihkan setelah update sukses.
- **Rollback otomatis:** jika aktivasi versi baru gagal (load/registrasi
  operasi error), kembalikan versi sebelumnya dan tandai update gagal.
- **Rollback manual:** tersedia di detail plugin selama versi sebelumnya
  masih disimpan. Downgrade selalu meminta konfirmasi eksplisit.
- **Downgrade dari registry:** hanya jika pengguna memilih versi lama
  secara eksplisit; versi `yanked`/`revoked` tidak boleh dipilih.
- **Plugin `deprecated`:** tetap dapat dipakai; tampilkan saran update.
- **Plugin `revoked`:** lihat §9.

## 9. Revocation & Moderasi

| Status | Instal baru | Plugin terpasang | Tindakan aplikasi |
|---|---|---|---|
| `active` | Boleh | Normal | — |
| `deprecated` | Boleh | Normal | Banner saran update |
| `yanked` | Ditolak | Tetap berjalan | Tawarkan update/rollback |
| `revoked` | Ditolak | Dinonaktifkan | Banner darurat, tawarkan hapus/rollback |

- Revocation disebarkan lewat indeks bertanda tangan; pengguna melihatnya
  saat membuka katalog. Tanpa jaringan, aplikasi tidak dapat mengetahui
  revocation terbaru — ini batasan yang harus ditampilkan di UI.
- Aplikasi tidak menghapus data pengguna secara otomatis. Operasi plugin
  `revoked` ditandai `unsupported` sampai pengguna menghapus atau
  melakukan rollback.
- Moderasi: plugin yang melanggar kebijakan dihapus dari indeks dan
  statusnya diubah menjadi `revoked`; riwayat rilis tetap dapat diaudit.

## 10. Keamanan & Error

Ancaman utama dan mitigasi:

| Ancaman | Mitigasi |
|---|---|
| Registry/CDN dimodifikasi | Signature indeks + signature paket; hash |
| Kunci signing dicuri | Kunci offline/HSM, rotasi, revocation lewat rilis aplikasi |
| MITM | TLS + signature; MITM hanya bisa memblokir, bukan memalsukan |
| Metadata ditukar | Seluruh indeks ditandatangani; manifest dicocokkan dengan entri |
| Replay indeks lama | `sequence` monoton + cache lokal |
| Downgrade ke versi rentan | Semver + konfirmasi eksplisit + status `yanked`/`revoked` |
| Cache lokal dirusak | Signature diverifikasi ulang saat cache dimuat |
| Paket berbahaya | Batas `.berp`, sandbox, izin, review kurasi (F16-T07/T08) |
| Disk penuh | Batas ukuran + pembersihan file sementara/cache |

Kode error yang direncanakan (prefix `registry.`):

`offline`, `consent_required`, `http`, `too_large`, `schema`,
`signature_invalid`, `key_unknown`, `key_revoked`, `replay`,
`entry_invalid`, `app_too_old`, `download_failed`, `hash_mismatch`,
`package_signature_invalid`, `manifest_mismatch`, `downgrade`,
`install_failed`, `cache_corrupt`.

Pesan pengguna berbahasa Indonesia; detail teknis masuk layar diagnostik
(F16-T06).

## 11. Acceptance Criteria F16

### F16-T01 — Registry client

- Model + parser `registry.json` v1 dengan validasi §4 dan batas ukuran.
- Fetch HTTPS + cache + `sequence` + fallback offline.
- Verifikasi signature indeks terintegrasi (dengan T03).
- Unit test: indeks valid, field hilang, tipe salah, versi tak didukung,
  replay, indeks kebesaran, cache korup, offline.
- Tidak ada UI pada task ini.

### F16-T03 — Signature Ed25519

- Verifier Ed25519 + trust store `assets/registry_keys.json`.
- Parsing signature file, penolakan keyId tak dikenal/revoked.
- Uji signature indeks dan paket, domain separation, signature salah,
  public key salah, ukuran/hash tidak cocok.
- Dependency kriptografi melalui review `ARCHITECTURE.md` §12.

### F16-T02 — UI katalog

- Layar katalog: daftar, pencarian, detail, status verifikasi, izin, ukuran,
  sumber, versi, dan status.
- Dialog konsen jaringan pertama + pengaturan cabut konsen.
- Cache/offline banner dan tombol perbarui.
- Dialog izin untuk `net`/`file:*` dan izin baru saat update.
- Instalasi end-to-end memakai T01/T03.

### F16-T04 — Update & rollback

- Deteksi update semver + badge.
- Retensi dua versi, rollback otomatis saat aktivasi gagal, rollback manual.
- Penanganan `yanked`/`revoked` dan notifikasi di katalog/Plugin Manager.
- Uji: update sukses, permission escalation, rollback, downgrade, revocation.

### F16-T08 — Tooling registry

- CLI: `validate`, `sign`, `build-index`, `verify`.
- Generate `registry.json` deterministik + naikkan `sequence`.
- Review checklist: source Lua, izin, lisensi, tidak ada obfuscation,
  hash/signature, batas paket.
- Publikasi atomik: paket + signature dulu, indeks bertanda tangan terakhir.

### Gate publik

- F16-T07 (audit/fuzzing sandbox dan parser) selesai 2026-11-20 (CP-076).
- Tidak ada temuan kritis/tinggi yang terbuka.

## 12. Keputusan Terbuka

| ID | Keputusan | Usulan | Status |
|---|---|---|---|
| D12 | Hosting, URL publik, dan CDN registry | GitHub Pages/repo + CDN; URL final saat implementasi | Terbuka (ditunda) |
| D13 | Custody kunci Ed25519, rotasi, dan revocation | Kunci indeks offline/HSM; kunci paket di CI; rotasi 90 hari | Terbuka |
| — | Library Ed25519 | `package:cryptography` (perlu review dependency) | Menunggu implementasi |
| — | TTL cache indeks | 24 jam | Usulan |
| — | Jumlah versi lama disimpan | 1 versi sebelumnya | Usulan |
| — | Registry pihak ketiga | Tidak ada di v1 | Usulan |
| — | Ikon plugin dari jaringan | Ditunda | Usulan |
| — | Kebijakan reset `sequence` | Tidak ada reset di v1 | Usulan |

Keputusan D12/D13 dicatat juga di `TODO.md` bagian D dan `progress.md` §8.

## 13. Rencana Implementasi (belum ada kode)

Rencana modul (nama dapat berubah saat implementasi):

```text
lib/core/registry/
  registry_index.dart        model + parser + validasi
  registry_signature.dart    Ed25519 verifier + signature file
  registry_trust_store.dart  public key yang di-pin
  registry_client.dart       HTTP, cache, sequence, offline
  registry_installer.dart    unduh, verifikasi, instal, provenance
lib/features/plugins/registry/
  registry_providers.dart
  registry_catalog_screen.dart
  registry_detail_screen.dart
tool/registry/
  validate.dart
  sign.dart
  build_index.dart
```

Fondasi yang sudah ada dan dapat dipakai ulang:

- `PluginPackageStore` untuk instalasi atomik dan versioning direktori.
- `PluginIntegrity` untuk SHA-256.
- `PluginManifest` untuk validasi manifest dan pencocokan entri.
- `PluginPermission` + dialog izin yang sudah ada.
- `PluginLifecycleService` + `OperationRegistry` untuk aktivasi.
- `InstalledPlugin` dan repository plugin untuk metadata terpasang
  (perlu migrasi kolom provenance).

## 14. Referensi

- [PLUGINS.md](PLUGINS.md) — manifest, format `.berp`, tier, izin.
- [THREAT_MODEL.md](THREAT_MODEL.md) — ancaman dan batas isolasi.
- [PRIVACY.md](PRIVACY.md) — komitmen offline dan perilaku jaringan.
- [ARCHITECTURE.md](ARCHITECTURE.md) — layer dan dependency.
- [TODO.md](TODO.md) — F16 dan keputusan D12/D13.
