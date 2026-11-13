# Bufferite — Kebijakan Privasi (Offline-first)

Bufferite dirancang **offline-first**. Data Anda tidak keluar dari perangkat.

## Data yang diproses

- Buffer/teks/byte yang Anda masukkan diproses **di perangkat**.
- Recipe tersimpan lokal di SQLite perangkat.
- Plugin disimpan lokal di penyimpanan aplikasi.
- File yang Anda pilih dibaca scoped saat itu dan tidak diunggah.

## Jaringan

- Tidak ada jaringan yang dipakai untuk memproses data atau menyimpan recipe.
- Katalog plugin (Fase 2) akan memakai jaringan **hanya setelah Anda memilih
  membukanya**, dengan peringatan eksplisit. Versi MVP belum mengaktifkan ini.
- Manifest aplikasi tidak meminta izin INTERNET pada rilis.

## Log

- Log eksekusi bersifat **opt-in** dan default mati.
- Anda dapat menghapus log kapan saja dari Settings.

## Izin plugin

- Plugin hanya dapat mengakses `cpu` secara default.
- `net`, `file:read`, `file:write` memerlukan persetujuan eksplisit lewat dialog.

## Reset data

- "Reset data" menghapus recipe, plugin, dan pengaturan dari perangkat dengan
  konfirmasi.