# Bufferite � Kebijakan Privasi (Offline-first)

Bufferite dirancang **offline-first**. Data Anda tidak keluar dari perangkat.

## Data yang diproses

- Buffer/teks/byte yang Anda masukkan diproses **di perangkat**.
- Recipe tersimpan lokal di SQLite perangkat.
- Plugin disimpan lokal di penyimpanan aplikasi.
- File yang Anda pilih dibaca scoped saat itu dan tidak diunggah.

## Jaringan

- Rilis 1.0 tidak memakai jaringan untuk memproses data atau menyimpan
  recipe. Build Fase 2 meminta izin Android `INTERNET` di manifest agar
  katalog plugin dapat diunduh; izin ini bersifat install-time.
- Meskipun izin ada, aplikasi tidak melakukan request jaringan sampai Anda
  membuka katalog dan menyetujui peringatan. Konsen disimpan lokal dan dapat
  dicabut di Settings.
- Saat aktif, aplikasi hanya melakukan `GET` untuk indeks dan paket yang
  Anda pilih. Buffer, recipe, dan file tidak pernah diunggah. Tidak ada
  sinkronisasi atau auto-update di latar belakang.
- Tidak ada cookie, akun, token, atau telemetri. Cache katalog disimpan
  lokal dan dapat dihapus dari Settings tanpa menghapus plugin terpasang.

## Log

- Log eksekusi bersifat **opt-in** dan default mati.
- Anda dapat menghapus log kapan saja dari Settings.

## Izin plugin

- Plugin hanya dapat mengakses `cpu` secara default.
- `net`, `file:read`, `file:write` memerlukan persetujuan eksplisit lewat dialog.

## Reset data

- "Reset data" menghapus recipe, plugin, dan pengaturan dari perangkat dengan
  konfirmasi.