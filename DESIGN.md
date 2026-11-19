# design.md — Bufferite Design System

Versi dokumen: 1.0
Status: Final (MVP)

## 1. Prinsip Desain
- Minimalis, simple, modern: banyak whitespace, hierarki jelas, tanpa ornamen
  berlebih.
- Referensi rasa: Vercel (bersih, monokrom, tipografi tegas, border tipis),
  tetapi tidak monoton—beri aksen kecil dan micro-interaction agar tidak
  membosankan.
- Konten adalah raja: UI tidak bersaing dengan data. Buffer dan recipe harus
  selalu jadi fokus.
- Touch-first: target sentuh besar, gestur jelas, drag and drop nyaman.
- Konsisten: satu bahasa visual untuk semua layar.
- Aksesibel: kontras cukup, dukungan screen reader, target sentuh minimal
  44x44 dp.
- Offline-first: tidak ada elemen yang bergantung pada jaringan kecuali
  katalog plugin (dengan peringatan).

## 2. Palet Warna
Pendekatan: monokrom netral + satu aksen utama + warna semantik terbatas.

Light mode:
- background:      #FFFFFF
- surface:         #FAFAFA
- surfaceAlt:      #F4F4F5
- border:          #E4E4E7
- borderStrong:    #D4D4D8
- textPrimary:     #09090B
- textSecondary:   #52525B
- textMuted:       #A1A1AA
- accent:          #2563EB   (biru; aksi utama)
- accentHover:     #1D4ED8
- accentSoft:      #EFF6FF
- success:         #16A34A
- warning:         #D97706
- danger:          #DC2626

Dark mode:
- background:      #09090B
- surface:         #121214
- surfaceAlt:      #18181B
- border:          #27272A
- borderStrong:    #3F3F46
- textPrimary:     #FAFAFA
- textSecondary:   #A1A1AA
- textMuted:       #71717A
- accent:          #3B82F6
- accentHover:     #60A5FA
- accentSoft:      #172554
- success:         #22C55E
- warning:         #F59E0B
- danger:          #EF4444

Aturan:
- Aksen hanya untuk aksi utama dan fokus; jangan dipakai untuk dekorasi.
- Warna semantik hanya untuk status (sukses, peringatan, error).
- Jangan memakai lebih dari satu aksen per layar.
- Kontras teks minimal 4.5:1 (WCAG AA).

## 3. Tipografi
- Font: Inter (atau system font sebagai fallback).
- Skala:
  - display:  28/34, weight 600
  - h1:       22/28, weight 600
  - h2:       18/24, weight 600
  - body:     15/22, weight 400
  - bodyStrong:15/22, weight 600
  - caption:  13/18, weight 400
  - mono:     14/20, weight 400 (JetBrains Mono / Roboto Mono)
- Mono wajib untuk buffer input/output, hex, hash, dan data teknis.
- Jangan memakai lebih dari 3 ukuran teks dalam satu kartu.

## 4. Spacing, Radius, Elevasi
- Spacing scale: 4, 8, 12, 16, 24, 32, 48.
- Padding default layar: 16 (mobile), 24 (tablet).
- Radius:
  - small: 8
  - medium: 12
  - large: 16
  - pill: 999
- Elevasi:
  - Gunakan border tipis (1px) alih-alih shadow untuk kesan Vercel.
  - Shadow hanya untuk elemen mengambang (FAB, bottom sheet, dialog):
    0 8 24 rgba(0,0,0,0.08) di light, 0 8 24 rgba(0,0,0,0.4) di dark.

## 5. Ikonografi
- Gaya: line icon, stroke 1.5–2, sudut membulat.
- Ukuran: 16 (inline), 20 (tombol), 24 (navigasi).
- Gunakan satu set ikon konsisten (misal Lucide).
- Ikon tanpa label hanya jika maknanya jelas; jika ragu, beri label.

## 6. Komponen Inti
### 6.1 Tombol
- Primary: background accent, teks putih, radius medium, tinggi 44.
- Secondary: background surfaceAlt, border 1px, teks textPrimary.
- Ghost: tanpa background, teks textSecondary; hover surfaceAlt.
- Danger: background danger untuk aksi destruktif.
- State: default, hover/pressed (opacity 0.9), disabled (opacity 0.4),
  loading (spinner kecil di kiri teks).
- Jangan memakai lebih dari satu primary button per layar.

### 6.2 Kartu Operasi (Recipe Step)
- Container: surface, border 1px, radius medium, padding 12.
- Isi: ikon drag handle (kiri), nama operasi + kategori dan badge
  tier/status (tengah, badge memakai wrap agar tidak overflow di panel
  sempit), status toggle enabled (kanan), tombol konfigurasi (chevron).
- State:
  - default: border normal.
  - dragging: elevasi naik, border accent, opacity 0.95.
  - disabled: opacity 0.5, teks muted, tidak bisa di-drag.
  - error: border danger, ikon peringatan, pesan singkat.
  - unsupported: badge "unsupported", tombol konfigurasi disabled.
- Gestur: long-press untuk drag; tap untuk buka konfigurasi; swipe kiri
  untuk hapus (dengan konfirmasi).

### 6.3 Buffer Panel (Input/Output)
- Container: surfaceAlt, border 1px, radius medium.
- Header: label ("Input" / "Output"), tipe (text/bytes/file), tombol copy,
  tombol expand.
- Body: area teks monospace, scroll, seleksi teks.
- Output live: indikator kecil "live" saat pipeline berjalan.
- Error: banner danger di bawah panel dengan pesan jelas.
- Empty state: teks muted "Belum ada data" + tombol "Tempel" / "Pilih file".

### 6.4 Operation Picker (Bottom Sheet)
- Tinggi: 85% layar; drag handle di atas.
- Search bar sticky di atas.
- Kategori sebagai chip horizontal (Encode/Decode, Crypto, Format,
  Analysis, Utility, Favorit).
- Daftar operasi: nama + deskripsi singkat + badge tier (dsl/lua/wasm) +
  ikon favorit.
- Tap operasi = tambah ke recipe dan tutup sheet.
- Empty state: "Tidak ada operasi cocok" + saran hapus filter.

### 6.5 Plugin Manager
- Daftar plugin: nama, versi, tier, izin, status (aktif/nonaktif),
  sumber (core/registry/sideload).
- Badge: "unverified" untuk sideload, "update tersedia" jika ada versi
  baru.
- Aksi: aktif/nonaktif, hapus, lihat detail (manifest, izin, operasi).
- Tombol "Instal dari file" (sideload) selalu terlihat.
- Tombol "Buka katalog" dengan peringatan akses jaringan.

### 6.6 Dialog Izin
- Judul jelas: "Plugin meminta akses internet".
- Body: penjelasan singkat + daftar izin + risiko.
- Aksi: "Batal" (secondary), "Setujui" (primary atau danger jika net).
- Tidak bisa ditutup dengan tap luar; harus pilih aksi.

### 6.7 Toast & Snackbar
- Posisi bawah, radius medium, border 1px.
- Durasi 3 detik; aksi "Undo" untuk aksi destruktif.
- Jenis: info, success, warning, error (warna semantik di ikon, bukan
  seluruh background).

### 6.8 Empty State
- Ikon line besar (48), judul h2, deskripsi caption, satu aksi utama.
- Contoh: "Belum ada recipe" + "Buat recipe baru".

### 6.9 Dialog Konfigurasi Step
- Muncul sebagai dialog tengah, bukan bottom sheet; lebar maksimum 480.
- Judul = nama operasi, isi = field parameter per tipe (string, integer,
  boolean, select) beserta bantuan.
- Konten dapat digulir; error validasi tampil di dalam dialog.
- Aksi: "Batal" (ghost) dan "Terapkan" (primary). Tap luar atau tombol
  tutup membatalkan tanpa mengubah args.

## 7. Navigasi
- Bottom navigation 3 tab: Home, Library, Settings.
- Home: daftar recipe tersimpan + tombol "Recipe Baru".
- Library: daftar operasi (dari plugin aktif) + pencarian.
- Settings: tema, plugin manager, tentang, privasi.
- Recipe Editor dibuka sebagai layar penuh (bukan tab) dengan tombol back.
- Panel step di Recipe Editor dibuka dari ikon Step di AppBar dan meluncur
  dari kanan (end drawer) berisi seluruh daftar step, tambah step, reorder,
  toggle, hapus, dan akses konfigurasi.
- Plugin Manager dibuka dari Settings.

## 8. Wireframe Tekstual (ASCII)

### 8.1 Home
+-----------------------------------+
| Bufferite            [search]  |
+-----------------------------------+
| [+ Recipe Baru]                   |
|                                   |
| Recipe Terbaru                    |
| +-------------------------------+ |
| | Base64 -> XOR 0x42            | |
| | 2 langkah · kemarin           | |
| +-------------------------------+ |
| +-------------------------------+ |
| | JSON Pretty                   | |
| | 1 langkah · 3 hari lalu       | |
| +-------------------------------+ |
|                                   |
| [empty state jika kosong]         |
+-----------------------------------+
| Home      Library      Settings   |
+-----------------------------------+

### 8.2 Recipe Editor
+-----------------------------------+
| <  Nama Recipe   [step] [menu][simpan] |
+-----------------------------------+
| Nama recipe                       |
| [.............................]   |
|                                   |
| Input                             |
| +-------------------------------+ |
| | SGVsbG8=                      | |
| |                    [copy][v]  | |
| +-------------------------------+ |
| [Pilih file]                      |
|                                   |
| Output                    [live]  |
| +-------------------------------+ |
| | Hello                         | |
| |                    [copy][v]  | |
| +-------------------------------+ |
+-----------------------------------+

Panel Step (meluncur dari kanan):
+-----------------------------------+
| Step (3)                     [x]  |
| [+ Tambah step]                   |
| +-------------------------------+ |
| | :: Base64 Decode      [on] v  | |
| +-------------------------------+ |
| | :: XOR               [on] v   | |
| +-------------------------------+ |
| | :: Hex to String     [off] v  | |
| +-------------------------------+ |
+-----------------------------------+

Tap kartu step (chevron) membuka dialog konfigurasi parameter di tengah
layar; daftar step tetap terlihat di panel kanan.

### 8.3 Operation Picker
+-----------------------------------+
|            ----                   |
| [search operasi.............]     |
| [Encode][Crypto][Format][Analysis]|
| [Utility][Favorit]                |
|                                   |
| Base64 Decode          lua   [*]  |
| Base64 Encode          lua   [ ]  |
| Hex Decode             dsl   [ ]  |
| AES Decrypt            wasm  [ ]  |
| ...                               |
+-----------------------------------+

### 8.4 Plugin Manager
+-----------------------------------+
| <  Plugin Manager     [instal file]|
+-----------------------------------+
| Core                              |
| +-------------------------------+ |
| | core.berp v1.0.0   aktif  v   | |
| | 120 operasi · core            | |
| +-------------------------------+ |
| Komunitas                         |
| +-------------------------------+ |
| | encoding-pack v1.2 lua        | |
| | aktif · unverified        v   | |
| +-------------------------------+ |
| [Buka katalog plugin]             |
+-----------------------------------+

### 8.5 Dialog Izin
+-----------------------------------+
| Plugin meminta akses internet     |
|                                   |
| encoding-pack ingin mengakses     |
| jaringan. Bufferite berjalan   |
| offline secara default.           |
|                                   |
| Izin: net                         |
|                                   |
|        [Batal]   [Setujui]        |
+-----------------------------------+

## 9. Motion & Micro-interaction
- Durasi: 150–200 ms untuk transisi kecil; 250 ms untuk bottom sheet dan
  panel step (end drawer).
- Easing: ease-out untuk masuk, ease-in untuk keluar.
- Drag: kartu terangkat (shadow + border accent) dan mengikuti jari.
- Reorder: animasi posisi 150 ms.
- Preview live: debounce 200 ms agar tidak terlalu sering.
- Haptic: light impact saat drag mulai, selection saat reorder.
- Jangan memakai animasi dekoratif yang mengganggu fokus data.

## 10. Aksesibilitas
- Kontras teks minimal 4.5:1; ikon minimal 3:1.
- Target sentuh minimal 44x44 dp.
- Label untuk semua ikon aksi (tooltip/semantik).
- Dukungan screen reader: setiap kartu operasi punya label "Operasi X,
  status aktif, tombol konfigurasi".
- Jangan mengandalkan warna saja untuk status; gunakan ikon/teks.
- Dukung ukuran font sistem (text scaling) hingga 1.3x tanpa layout rusak.

## 11. Dark Mode
- Default mengikuti sistem; bisa diubah di Settings.
- Tidak ada pure black (#000) untuk background; gunakan #09090B.
- Aksen sedikit lebih terang di dark mode.
- Border tetap tipis; jangan memakai shadow berlebih.

## 12. Prinsip Anti-Bosan (agar tidak monoton)
- Satu aksen warna yang konsisten, dipakai hemat.
- Micro-interaction halus pada drag, reorder, dan preview live.
- Tipografi tegas (heading weight 600) memberi karakter.
- Empty state yang ramah dengan ilustrasi line sederhana (bukan clipart).
- Gunakan badge kecil (tier, status) untuk memberi detail visual tanpa
  dekorasi.
- Hindari gradient, glassmorphism, dan shadow berlebih.

## 13. Komponen yang Tidak Boleh Ada
- Gradient dekoratif.
- Shadow berlapis.
- Animasi berlebihan (>300 ms untuk interaksi inti).
- Warna aksen lebih dari satu per layar.
- Ikon berwarna-warni tanpa makna.

## 14. Referensi Visual
- Vercel Dashboard: minimal, monokrom, tipografi tegas, border tipis.
- Linear: micro-interaction halus, dark mode nyaman.
- Raycast: kepadatan informasi yang rapi, search-first.
- Catatan: ambil prinsipnya, bukan meniru identitas visualnya.

## 15. Checklist Desain Sebelum Rilis
- [ ] Kontras teks dan ikon memenuhi WCAG AA.
- [ ] Target sentuh minimal 44x44 dp.
- [ ] Dark mode dan light mode konsisten.
- [ ] Drag and drop nyaman di layar kecil dan besar.
- [ ] Empty state tersedia untuk Home, Library, Plugin Manager, Output.
- [ ] Dialog izin tidak bisa ditutup tanpa memilih aksi.
- [ ] Preview live tidak membuat UI lag (debounce).
- [ ] Text scaling 1.3x tidak merusak layout.
- [ ] Tidak ada gradient, shadow berlebih, atau aksen ganda.
- [ ] Semua ikon aksi punya label semantik.

## 16. Pertanyaan Terbuka
- Finalisasi font: Inter vs system font (perlu uji di Android/iOS).
- Ilustrasi empty state: buat sendiri atau pakai set open-source?
- Perlu mode "fokus" (sembunyikan navigasi saat mengedit recipe)?
