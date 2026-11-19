# Bufferite � Kebijakan Privasi (Offline-first)

Bufferite dirancang **offline-first**. Data Anda tidak keluar dari perangkat.

## Data yang diproses

- Buffer/teks/byte yang Anda masukkan diproses **di perangkat**.
- Recipe tersimpan lokal di SQLite perangkat.
- Plugin disimpan lokal di penyimpanan aplikasi.
- File yang Anda pilih dibaca scoped saat itu dan tidak diunggah.

## Jaringan

- Rilis 1.0 tidak memakai jaringan untuk memproses data atau menyimpan
  recipe, dan manifest aplikasi tidak meminta izin INTERNET.
- Katalog plugin (Fase 2, spesifikasi `REGISTRY.md`) hanya mengakses
  jaringan setelah Anda membuka katalog dan menyetujui peringatan.
- Saat aktif, aplikasi hanya melakukan `GET` untuk indeks dan paket yang
  Anda pilih. Buffer, recipe, dan file tidak pernah diunggah.
- Tidak ada cookie, akun, token, atau telemetri. Cache katalog disimpan
  lokal dan dapat dihapus dari Settings; konsen dapat dicabut.
- Izin INTERNET baru ditambahkan ke manifest saat fitur registry dirilis.

## Log

- Log eksekusi bersifat **opt-in** dan default mati.
- Anda dapat menghapus log kapan saja dari Settings.

## Izin plugin

- Plugin hanya dapat mengakses `cpu` secara default.
- `net`, `file:read`, `file:write` memerlukan persetujuan eksplisit lewat dialog.

## Reset data

- "Reset data" menghapus recipe, plugin, dan pengaturan dari perangkat dengan
  konfirmasi.