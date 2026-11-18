# Review Keamanan Kripto Lanjutan (F13-T09)

Tanggal: 2026-11-19. Lingkup: AES, XOR, dan HMAC varian di `core.berp`.

## Konteks

Bufferite adalah alat transformasi data offline. Input, kunci, dan IV
sepenuhnya berasal dari pengguna; aplikasi tidak menyimpan kunci, tidak
mengirim data keluar, dan tidak punya izin INTERNET. Operasi kripto di sini
adalah *transformasi mentah* seperti CyberChef, bukan penyimpanan rahasia.

## Keputusan

| Topik | Keputusan | Alasan |
|---|---|---|
| Mode AES | CBC (PKCS#7) dan CTR | Umum, deterministik, mudah diverifikasi |
| ECB | Tidak disediakan | Bocor pola blok; tidak ada use case aman |
| GCM/CCM | Ditunda | Butuh UX tag autentikasi; di luar cakupan MVP |
| Kunci/IV | Hex wajib, tanpa default | Menghindari kunci lemah/IV dipakai ulang tanpa sadar |
| Panjang kunci | 16/24/32 byte (AES-128/192/256) | Validasi dini, error jelas |
| IV | 16 byte | Ukuran blok AES |
| XOR | Tersedia dengan label obfuscation | Bukan enkripsi; jangan diklaim aman |
| HMAC | SHA-1/256/512; SHA-256 default | SHA-1 hanya kompatibilitas |
| Penyimpanan kunci | Tidak ada; parameter `secret` | Tidak ada log/telemetri kunci |
| Batas input | 5 MiB | Cegah kehabisan memori/UI freeze |

## Risiko yang diterima

- **Tanpa autentikasi (CBC/CTR).** Ciphertext dapat dimodifikasi tanpa
  terdeteksi. UI memberi `helpText` bahwa operasi ini bukan untuk menyimpan
  rahasia; GCM ditunda.
- **Zeroization tidak dijamin.** Dart/GC tidak menyediakan penghapusan memori
  yang deterministik. Kunci bisa tetap di heap sampai GC.
- **Timing.** Tidak ada operasi verifikasi/tag, jadi tidak ada perbandingan
  rahasia yang perlu constant-time.
- **MD5/SHA-1/HMAC-SHA1.** Hanya untuk kompatibilitas; pemilihan algoritma
  ada di tangan pengguna.

## Mitigasi teknis

- Semua error memakai `AppError` tanpa menyertakan kunci/IV.
- Hex divalidasi ketat (genap, karakter valid); Base64 gagal → error jelas.
- Hasil dekripsi non-UTF-8 memberi saran memilih keluaran Hex/Base64.
- Tidak ada dependensi kripto baru selain `pointycastle` (MIT), yang juga
  dipakai untuk AES; HMAC memakai `package:crypto`.

## Verifikasi

`test/core/operations/crypto_test.dart` mencakup:

- AES-CBC roundtrip (hex & base64), AES-CTR keystream NIST SP 800-38A,
  roundtrip UTF-8, kunci/IV invalid, Base64 rusak, hasil non-UTF-8.
- XOR teks/hex/base64 dan kunci kosong.
- HMAC-SHA1 dan HMAC-SHA512 vektor referensi.

## Di luar cakupan

GCM/CCM, PBKDF2/scrypt/Argon2, RSA/EC, enkripsi file besar/streaming, dan
penyimpanan kunci terenkripsi.