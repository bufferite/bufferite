# registry.md — Spesifikasi Registry Plugin Bufferite

Versi dokumen: 1.0 (draf)
Status: **Selesai untuk v1** — tooling registry, hosting, model/signature core,
client read-only, UI katalog + instalasi terverifikasi (F16-T02),
update/rollback (F16-T04), dan trust anchor produksi (D13) tersedia.
Publikasi CI masih menunggu repo/Pages/secret operasional.
Berlaku untuk: registry resmi read-only Bufferite
Dokumen terkait: [PLUGINS.md](PLUGINS.md), [THREAT_MODEL.md](THREAT_MODEL.md),
[PRIVACY.md](PRIVACY.md)

## 1. Status & Ruang Lingkup

Registry adalah katalog plugin `.berp` yang dapat dilihat dan diinstal dari
dalam aplikasi. Registry resmi bersifat **read-only**, **statis**, dan
**opsional**: aplikasi tetap berjalan penuh secara offline tanpa registry.

Per 2026-11-20, tooling registry (F16-T08), hosting (D12), client read-only
(F16-T01), UI katalog + instalasi terverifikasi (F16-T02), update/rollback
(F16-T04), dan keputusan custody kunci (D13) sudah selesai. Trust store
produksi (`assets/registry_keys.json`) dibundel di aplikasi; signing indeks
dilakukan offline, kunci paket berada di CI.

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
- Hosting pihak ketiga atau URL kustom dari pengguna (hosting resmi D12
  sudah diputuskan, lihat §3).

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

Hosting v1 diputuskan di D12 (2026-11-20): GitHub Pages dari repo
`bufferite/plugins` di org `bufferite`, disajikan pada domain kanonis
`https://plugins.bufferite.dev`. Aplikasi hanya membaca
`https://plugins.bufferite.dev/registry/v1/registry.json` dan signature-nya.
DNS CNAME harus aktif sebelum client registry dirilis; jangan mengganti URL
setelah rilis. `allowedHosts` v1 hanya berisi `plugins.bufferite.dev`.

Kontribusi lewat pull request ke repo registry; branch bukan kanal publikasi.
Hanya hasil deploy dari `main` yang dibaca aplikasi. Scaffold repo tersedia di
[`registry-scaffold/`](registry-scaffold/).

Persyaratan minimum:

- HTTPS dengan sertifikat valid; tidak ada HTTP atau cleartext.
- File statis, read-only, dan dapat di-cache CDN.
- URL paket **immutable**: satu URL hanya untuk satu versi paket.
- `Content-Type: application/json` untuk indeks dan signature;
  `application/octet-stream` untuk `.berp`.

Tata letak:

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

Public key di-pin di aplikasi melalui `assets/registry_keys.json`:

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
- **Rotasi paket:** setiap 90 hari. Kunci baru di-pin lewat rilis aplikasi,
  private key baru dipasang sebagai secret CI, lalu paket ditandatangani ulang
  pada publish berikutnya. Kunci lama dipertahankan minimal 90 hari sebelum
  `revoked`.
- **Rotasi indeks:** setiap 12 bulan. Kunci baru dibuat di mesin offline,
  public key di-pin lewat rilis aplikasi, dan kunci lama dipertahankan minimal
  90 hari. Setelah indeks ditandatangani ulang, kunci lama dicabut lewat rilis
  aplikasi berikutnya.
- **Custody (D13):** kunci indeks offline/air-gapped dan signing manual; kunci
  paket di secret environment CI `registry-publish` dengan required reviewers.
- Aset `assets/registry_keys.json` dibundel di aplikasi dan berisi kunci
  `official-index-2026-11` serta `official-package-2026-11` (keduanya aktif).
  Bila aset hilang, katalog menampilkan `registry.trust_store_missing` dan
  tidak melakukan fallback trust-all.

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
- **Izin platform:** `INTERNET` ada di manifest aplikasi sejak F16-T02.
  Izin Android bersifat install-time, sehingga pembatasan akses dilakukan di
  aplikasi: tidak ada request sebelum konsen, dan konsen dapat dicabut.
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

Implementasi F16-T02: `RegistryInstaller` menjalankan langkah 5-7,
`RegistryInstallService` menjalankan langkah 8-9, dan UI memakai
`RegistryCatalogScreen`/`RegistryDetailScreen`. Dialog izin memakai komponen
`showPermissionDialog` yang sama dengan sideload; saat update hanya izin yang
bertambah yang diminta ulang (F16-T04).

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

Implementasi F16-T04 (CP-081): `registry_plugin_status.dart` menghitung rilis
pembaruan dan status terpasang; `PluginManagerService.update` menyimpan dua
versi, mempertahankan status enable/disable, dan memulihkan versi lama bila
aktivasi gagal; `PluginManagerService.rollback` memakai manifest versi
sebelumnya dari `<root>/<pluginId>/<version>`. Badge update/revocation tampil
di Plugin Manager dan katalog; detail katalog menyediakan pemilih versi
eksplisit untuk downgrade. Revocation dari cache/refresh menonaktifkan plugin
terpasang, tetapi tidak menghapus data pengguna.

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

Kode error (prefix `registry.`):

`offline`, `consent_required`, `http`, `too_large`, `schema`,
`signature_invalid`, `key_unknown`, `key_revoked`, `key_invalid`,
`trust_store_missing`, `replay`, `entry_invalid`, `app_too_old`,
`download_failed`, `hash_mismatch`, `package_signature_invalid`,
`manifest_mismatch`, `downgrade`, `install_failed`, `cache_corrupt`,
`cache_io`.

Pesan pengguna berbahasa Indonesia; detail teknis masuk layar diagnostik
(F16-T06).

## 11. Acceptance Criteria F16

### F16-T01 - Registry client

Selesai 2026-11-20 (CP-079): client read-only dengan transport HTTPS,
cache file, replay guard, fallback offline, dan verifikasi signature memakai
trust store yang diinjeksi. UI katalog ditambahkan di F16-T02 (CP-080).

- [x] Model + parser `registry.json` v1 dengan validasi §4 dan batas ukuran.
- [x] URL awal `https://plugins.bufferite.dev/registry/v1/registry.json` (D12).
- [x] Fetch HTTPS + cache + `sequence` + fallback offline.
- [x] Verifikasi signature indeks terintegrasi (dengan T03).
- [x] Unit test: indeks valid, field hilang, tipe salah, versi tak didukung,
      replay, indeks kebesaran, cache korup, offline.
- [x] Tidak ada UI pada task ini.

### F16-T03 — Signature Ed25519

Selesai 2026-11-20 (CP-082): verifier, trust store, signature indeks/paket,
dan trust anchor produksi sudah aktif. Kunci indeks `official-index-2026-11`
disimpan offline; kunci paket `official-package-2026-11` berada di secret CI.

- [x] Verifier Ed25519 + trust store `assets/registry_keys.json`.
- [x] Parsing signature file, penolakan keyId tak dikenal/revoked.
- [x] Uji signature indeks dan paket, domain separation, signature salah,
      public key salah, ukuran/hash tidak cocok.
- [x] Dependency kriptografi melalui review `ARCHITECTURE.md` §12.

### F16-T02 — UI katalog

Selesai 2026-11-20 (CP-080): katalog read-only dengan pencarian, detail,
konsen jaringan, banner cache/offline, dan instalasi terverifikasi. Sejak D13
selesai, trust anchor produksi dibundel di `assets/registry_keys.json`.

- [x] Layar katalog: daftar, pencarian, detail, status verifikasi, izin,
      ukuran, sumber, versi, dan status.
- [x] Dialog konsen jaringan pertama + pengaturan cabut konsen.
- [x] Cache/offline banner dan tombol perbarui.
- [x] Dialog izin untuk `net`/`file:*` dan izin baru saat update.
- [x] Instalasi end-to-end memakai T01/T03.
- [x] Test installer (sukses, ukuran, hash, signature, manifest, host,
      too_large) dan widget katalog/detail/konsen.

### F16-T04 — Update & rollback

Selesai 2026-11-20 (CP-081): deteksi update, badge, retensi dua versi,
rollback otomatis/manual, pemilih versi untuk downgrade eksplisit, dan
penonaktifan plugin `revoked` dari cache/refresh katalog. Trust anchor
produksi tersedia sejak D13 selesai (CP-082).

- [x] Deteksi update semver + badge.
- [x] Retensi dua versi, rollback otomatis saat aktivasi gagal, rollback manual.
- [x] Penanganan `yanked`/`revoked` dan notifikasi di katalog/Plugin Manager.
- [x] Uji: update sukses, permission escalation, rollback, downgrade, revocation.

### F16-T08 — Tooling registry

Selesai 2026-11-20 (CP-077). Detail di §13.2-§13.4.

- [x] CLI: `keygen`, `validate`, `sign`, `build-index`, `verify`.
- [x] Generate `registry.json` deterministik + naikkan `sequence`; sequence
      eksplisit yang tidak lebih besar dari indeks lama ditolak.
- [x] Review checklist: source Lua, izin, lisensi, tidak ada obfuscation,
      hash/signature, batas paket.
- [x] Publikasi atomik: paket + signature dulu, indeks bertanda tangan
      terakhir.
- [x] Signing produksi (D13): kunci indeks offline/air-gapped, kunci paket di
      secret CI; `keygen` lokal menulis file JSON tanpa enkripsi untuk dev/CI.

### Gate publik

- F16-T07 (audit/fuzzing sandbox dan parser) selesai 2026-11-20 (CP-076).
- Tidak ada temuan kritis/tinggi yang terbuka.

## 12. Keputusan & Status

| ID | Keputusan | Keputusan/Usulan | Status |
|---|---|---|---|
| D12 | Hosting, URL publik, dan CDN registry | GitHub Pages dari `bufferite/plugins` di `plugins.bufferite.dev`; PR + deploy atomik | Selesai (2026-11-20) |
| D13 | Custody kunci Ed25519, rotasi, dan revocation | Kunci indeks offline/air-gapped (signing manual); kunci paket di secret CI `registry-publish`; rotasi paket 90 hari, indeks 12 bulan; overlap 90 hari; revocation lewat rilis trust store | Selesai (2026-11-20) |
| — | Library Ed25519 | `package:cryptography` 2.9.0 (pure Dart) | Diterima — F16-T08 (CP-077) |
| — | TTL cache indeks | 24 jam | Diterima — F16-T01/T02 |
| — | Jumlah versi lama disimpan | 1 versi sebelumnya | Diterima — F16-T04 (CP-081) |
| — | Registry pihak ketiga | Tidak ada di v1 | Usulan |
| — | Ikon plugin dari jaringan | Ditunda | Usulan |
| — | Kebijakan reset `sequence` | Tidak ada reset di v1 | Usulan |

Keputusan D12/D13 dicatat juga di `TODO.md` bagian D dan `progress.md` §8.

Catatan D12: scaffold repo ada di `registry-scaffold/`. Workflow validasi PR
berjalan tanpa secret; workflow build/publish memakai environment
`registry-publish` dengan required reviewers. Branch bukan kanal publikasi;
hanya `registry.json` bertanda tangan hasil deploy dari `main` yang dibaca
aplikasi. Publish belum berjalan karena repo `bufferite/bufferite` belum
terisi, Pages/DNS belum aktif, dan secret kunci belum dipasang.

Catatan D13: `keygen` hanya membuat file kunci lokal tanpa enkripsi. Kunci
indeks produksi (`official-index-2026-11`) wajib dipindahkan ke media
offline/air-gapped dan tidak pernah masuk CI; kunci paket
(`official-package-2026-11`) disimpan sebagai secret environment
`REGISTRY_PACKAGE_KEY`. `publish.yml` hanya menandatangani paket dan membangun
indeks; indeks ditandatangani manual lalu di-commit ke `release/`;
`deploy.yml` memverifikasi signature dan mencocokkan rebuild deterministik
sebelum deploy. Trust store publik yang sama ada di `assets/registry_keys.json`
dan `registry-scaffold/keys/registry_keys.json`. Rotasi/revocation mengikuti
§5.3; aplikasi lama tetap memakai trust store lamanya sampai diperbarui.

## 13. Implementasi & Tooling

### 13.1 Status modul

```text
lib/core/registry/
  registry_index.dart        model + parser + validasi            (F16-T08)
  registry_signature.dart    Ed25519, signature file, trust store (F16-T08)
  registry_client.dart       HTTP, cache, sequence, offline       (F16-T01)
  registry_cache.dart        model cache indeks + signature        (F16-T01)
  registry_cache_store.dart  cache file atomik di app support      (F16-T01)
  registry_transport.dart    transport HTTPS + redirect           (F16-T01)
  registry_error.dart        error jaringan/cache                 (F16-T01)
  registry_installer.dart    unduh, verifikasi, cocokkan manifest, provenance (F16-T02)
  registry_plugin_status.dart status update/revocation plugin terpasang  (F16-T04)
lib/features/plugins/registry/
  registry_providers.dart             client/install/provider + konsen  (F16-T02)
  registry_catalog_screen.dart        daftar, cari, refresh, banner       (F16-T02/T04)
  registry_detail_screen.dart         detail + izin + versi + instalasi   (F16-T02/T04)
  registry_consent.dart               dialog & persistensi konsen         (F16-T02)
  registry_error_text.dart            pesan error registry ID/EN          (F16-T02)
tool/
  registry_cli.dart          entry point CLI                     (F16-T08)
  registry/
    registry_builder.dart    source -> registry.json deterministik (F16-T08)
registry-scaffold/
  .github/workflows/         validasi PR + build/publish + deploy (D12/D13)
```

Tooling F16-T08, hosting D12, client F16-T01, UI katalog/instalasi F16-T02,
update/rollback F16-T04, dan custody kunci/signing D13 selesai 2026-11-20.
Publikasi CI masih menunggu repo `bufferite/plugins`, Pages/DNS, dan secret
operasional.

### 13.2 CLI registry

Jalankan dari root repo (`dart run tool/registry_cli.dart help`).

| Perintah | Kegunaan |
|---|---|
| `keygen` | Buat pasangan kunci Ed25519 + trust store awal (lokal/CI). |
| `validate package` | Decode paket, cek batas, `integrity.sha256`, dan signature opsional. |
| `validate index` | Parse `registry.json`, batas, duplikat, dan URL vs `allowedHosts`. |
| `sign package` | Tulis `<paket>.berp.sig` dengan domain package. |
| `sign index` | Tulis `registry.json.sig` dengan domain index. |
| `build-index` | Gabungkan source + manifest paket menjadi `registry.json`. |
| `verify package` | Verifikasi signature paket terhadap keyring. |
| `verify index` | Verifikasi signature indeks terhadap keyring. |

Contoh alur rilis (produksi memisahkan kunci index offline dan kunci package
CI sesuai D13):

```powershell
# Di mesin CI/administratif:
dart run tool/registry_cli.dart keygen --key-id official-package-2026-11 \
  --usage package --out .keys/package.json \
  --public-out .keys/package-public.json

# Di mesin offline/air-gapped:
dart run tool/registry_cli.dart keygen --key-id official-index-2026-11 \
  --usage index --out D:\offline\official-index-2026-11.json \
  --public-out D:\offline\official-index-public.json

# Gabungkan kedua public key menjadi assets/registry_keys.json dan
# registry-scaffold/keys/registry_keys.json sebelum rilis aplikasi.

dart run tool/registry_cli.dart validate package \
  --in dist/packages/com.contoh.encoding-pack/1.2.0/encoding-pack-1.2.0.berp
dart run tool/registry_cli.dart sign package \
  --in dist/packages/com.contoh.encoding-pack/1.2.0/encoding-pack-1.2.0.berp \
  --out dist/packages/com.contoh.encoding-pack/1.2.0/encoding-pack-1.2.0.berp.sig \
  --key .keys/package.json

dart run tool/registry_cli.dart build-index --source registry-source.json \
  --out dist/registry.json --base dist/registry-lama.json \
  --keyring registry-scaffold/keys/registry_keys.json

# Di mesin offline:
dart run tool/registry_cli.dart sign index --in dist/registry.json \
  --out dist/registry.json.sig --key D:\offline\official-index-2026-11.json

dart run tool/registry_cli.dart verify index --in dist/registry.json \
  --sig dist/registry.json.sig \
  --keyring registry-scaffold/keys/registry_keys.json \
  --base-url https://plugins.bufferite.dev/registry/v1/registry.json
```

`keygen` menolak menimpa file yang sudah ada tanpa `--force`, termasuk
`--public-out`; file kunci ditulis tanpa enkripsi, jadi jangan commit.
`build-index` menulis file tujuan secara atomik (temporary + rename).

Input `build-index` adalah `registry-source.json` yang tidak dipublikasikan:

```json
{
  "baseUrl": "https://registry.contoh.dev/registry/v1/registry.json",
  "allowedHosts": ["registry.contoh.dev", "cdn.contoh.dev"],
  "generatedAt": "2026-11-20T12:00:00Z",
  "packages": [
    {
      "path": "packages/com.contoh.encoding-pack/1.2.0/encoding-pack-1.2.0.berp",
      "summary": "Kumpulan operasi encoding tambahan.",
      "publishedAt": "2026-11-20T10:00:00Z",
      "status": "active",
      "tags": ["encoding"]
    }
  ]
}
```

- `path` relatif terhadap file source dan wajib berada di `packages/...`
  kecuali `downloadUrl` diisi eksplisit.
- `pluginId`, `version`, `name`, `tier`, `minAppVersion`, `permissions`,
  `sizeBytes`, dan `sha256` selalu dibaca dari paket/manifest. `pluginId`
  dan `version` di source hanya untuk verifikasi silang.
- Metadata opsional source menimpa manifest: `description`, `author`,
  `license`, `homepage`. Field khusus indeks: `summary`, `publishedAt`,
  `status`, `tags`, `downloadUrl`, `signatureUrl`.
- File `<paket>.berp.sig` wajib ada. Dengan `--keyring`, signature
  diverifikasi; tanpa `--keyring` hanya keberadaan dan ukuran yang dicek.
  Selalu pakai `--keyring` di CI rilis.
- Determinisme: entri diurutkan `pluginId` lalu versi; `generatedAt`
  dipilih dari `--generated-at` > source > `publishedAt` terbaru > indeks
  lama > epoch; `sequence` default `indeks lama + 1`, dan nilai eksplisit
  harus lebih besar dari indeks lama. Output byte-identik untuk input sama.
  `--base` yang diberikan tetapi tidak ditemukan ditolak, bukan diam-diam
  memulai ulang dari `sequence` 1.
- Batas: indeks 5 MiB, signature 4 KiB, paket 32 MiB, 2.000 entri, dan
  1-8 `allowedHosts`.

### 13.3 Review checklist

- [ ] Paket lolos `validate package`; `pluginId` dan versi cocok manifest.
- [ ] Source Lua dibaca baris per baris; tidak ada obfuscation,
      `load`/bytecode dinamis, akses jaringan/FS tersembunyi, atau data
      pengguna yang dikirim keluar.
- [ ] Tier WASM dibangun dari source yang direview dan dapat direproduksi;
      hash paket dicatat.
- [ ] Izin minimal dan dijelaskan: `net`, `file:read`, `file:write` hanya bila
      fitur membutuhkannya.
- [ ] Lisensi ada dan kompatibel; `summary`/`description` teks biasa, tanpa
      markup/HTML.
- [ ] Tidak ada secret, token, atau data pribadi di paket.
- [ ] `sha256`, ukuran, dan signature cocok; `keyId` sesuai trust store dan
      belum revoked.
- [ ] `status` benar (`active`, `deprecated`, `yanked`, `revoked`) dan
      `sequence` lebih besar dari indeks publik sebelumnya.
- [ ] URL final HTTPS dan host hanya dari `allowedHosts`; path paket imutabel.

`validate package` memberi warning untuk lisensi kosong dan izin `net`/file,
tetapi warning bukan pengganti review manual.

### 13.4 Publikasi atomik

Urutan wajib:

1. Unggah `.berp` + `.sig` ke path versi yang tidak akan ditimpa.
2. Pastikan paket dapat diunduh dan hash-nya sama dengan entri.
3. Tanda tangani `registry.json`, lalu unggah `registry.json` + `.sig`
   terakhir. Jangan pernah menerbitkan indeks sebelum paket tersedia.
4. Jika ada kesalahan, jangan turunkan `sequence` dan jangan timpa paket;
   tandai `yanked`/`revoked`, lalu terbitkan indeks baru dengan `sequence`
   lebih tinggi.
5. Simpan `registry-source.json`, indeks, dan signature lama untuk audit.

Di GitHub, scaffold `registry-scaffold/` memakai dua workflow:
`publish.yml` menandatangani paket dengan kunci package CI dan membangun
indeks (artifact, belum deploy); signing indeks dilakukan manual di mesin
offline dan hasilnya di-commit ke `release/`; `deploy.yml` memverifikasi
signature, membangun ulang indeks secara deterministik, lalu men-deploy
`actions/deploy-pages` sehingga paket + indeks terbit dalam satu deployment
atomik. Workflow PR memakai kunci sementara tanpa secret (lihat catatan D13
di §12).

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
