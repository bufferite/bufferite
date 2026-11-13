# Audit Lisensi Operasi Core (F13-T10)

Semua operasi core pada MVP ditulis ulang dari spesifikasi umum (RFC) tanpa
memakai kode pihak ketiga, kecuali yang dicatat di bawah. Tidak ada operasi
yang mengadaptasi kode berlisensi GPL/AGPL.

## Ringkasan per operasi

| Kelompok | Operasi | Sumber | Lisensi |
|---|---|---|---|
| Encode/Decode | `core.base64_*`, `core.hex_*`, `core.url_*`, `core.html_entity_*` | Implementasi sendiri (`dart:convert`) | MIT (proyek) |
| Encode/Decode | `core.base32_*` | RFC 4648, implementasi sendiri | MIT (proyek) |
| Hash/Crypto | `core.md5`, `core.sha1`, `core.sha256`, `core.sha512`, `core.hmac_sha256` | `package:crypto` (Dart team) | BSD-3-Clause |
| Format | `core.json_prettify`, `core.json_minify` | `dart:convert` | BSD-3-Clause |
| Format | `core.jwt_decode` | Implementasi sendiri (tanpa verifikasi tanda tangan) | MIT (proyek) |
| Analysis | `core.entropy`, `core.frequency`, `core.file_type`, `core.strings` | Implementasi sendiri | MIT (proyek) |
| Utility | `core.upper_case` … `core.unique_lines` | Implementasi sendiri | MIT (proyek) |

## Dependency

- `package:crypto` — BSD-3-Clause (Dart team). Dipakai untuk hash/HMAC.
- Tidak ada dependency baru ditambahkan khusus operasi core.

## Catatan

- MD5 dan SHA-1 disediakan hanya untuk kompatibilitas, bukan untuk keamanan.
- Operasi kripto lanjutan (AES/XOR/HMAC varian, F13-T09) belum diimplementasikan
  dan menunggu review keamanan sebelum ditambahkan.
- Atribusi ini wajib ikut dalam paket `core.berp`/README (lihat `README.md` §6).
