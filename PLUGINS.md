# plugins.md — Bufferite Plugin System

Versi dokumen: 1.0
Status: Final (MVP)

## 1. Filosofi
Bufferite hidup dari komunitas. Fitur inti (recipe builder, pipeline)
disediakan aplikasi; kemampuan baru—converter, transformer, analisis
domain-spesifik—datang dari plugin yang dibuat komunitas. Plugin harus
transparan, dapat diverifikasi, dan tidak mengorbankan privasi pengguna.

## 2. Prinsip
- Offline-first: aplikasi tidak mengakses jaringan secara default.
- Explicit consent: akses jaringan hanya jika pengguna membuka katalog
  plugin, atau plugin meminta izin "net" dan pengguna menyetujui lewat
  dialog peringatan SEBELUM instalasi.
- Transparansi: source plugin dapat dibaca dan direview.
- Sandbox: setiap runtime membatasi resource dan kemampuan.
- Versioned: manifest, registry, dan kontrak operasi memiliki versi.
- Graceful degradation: plugin yang tidak didukung tidak membuat aplikasi
  crash; operasi ditandai "unsupported".
- Integritas berlapis: runtime WASM di-pin hash; paket plugin diverifikasi
  hash.

## 2A. Prinsip Inti Minimal
Aplikasi ini pada dasarnya adalah plugin interpreter + recipe engine + UI.
Tidak ada operasi pengolahan data yang di-hardcode di inti aplikasi. Semua
operasi—termasuk encoding, crypto, format, dan analysis—adalah plugin.

Yang berada di inti (hardcoded di aplikasi):
- Recipe engine dan pipeline executor.
- Plugin loader dan runtime (DSL, Lua native/WASM, WASM).
- Sandbox dan manajemen izin.
- Storage (recipe, plugin, setting).
- UI (Home, Recipe Editor, Operation Picker, Settings, Plugin Manager).

Yang TIDAK berada di inti:
- Operasi encode/decode, encrypt/decrypt, konversi format, analisis data.
- Semua itu disediakan oleh plugin, termasuk plugin core.

Manfaat:
- Ukuran aplikasi kecil dan cepat.
- Permukaan serang kecil (semua logika asing di sandbox).
- Aplikasi hidup dari komunitas; operasi inti pun bisa diperbarui lewat
  plugin tanpa merilis ulang aplikasi.
- Konsisten: satu kontrak operasi untuk semua.

Konsekuensi yang dikelola:
- First-run experience: diselesaikan dengan plugin core yang dibundel dan
  diinstal otomatis (lihat 2B).
- Kontrak plugin harus sangat stabil dan versioned.
- UI wajib menangani kondisi "belum ada plugin" dengan empty state yang
  mengarahkan ke katalog/sideload, bukan error.

## 2B. Bootstrap & Plugin Core
- Aplikasi membundel satu paket plugin core: core.berp.
- core.berp berisi hampir semua operasi yang ada di CyberChef,
  dikelompokkan per kategori (Encode/Decode, Crypto, Format, Analysis,
  Utility).
- Saat first-run, core.berp diinstal otomatis dari aset aplikasi (bukan
  diunduh). Pengguna langsung bisa memakai operasi inti.
- core.berp diperlakukan sama seperti plugin lain: memiliki manifest,
  diverifikasi SHA-256 (hash di-pin di aplikasi), dan tunduk pada sandbox
  serta model izin yang sama.
- core.berp dapat diperbarui lewat mekanisme plugin biasa (registry atau
  sideload) tanpa merilis ulang aplikasi, selama minAppVersion terpenuhi.
- Pengguna dapat menonaktifkan atau menghapus core.berp, tetapi aplikasi
  akan menampilkan peringatan bahwa operasi dasar tidak akan tersedia.
- Sideload .berp selalu tersedia sebagai jalur instalasi mandiri.

## 3. Model Tier Runtime
Ketiga tier adalah satu kesatuan MVP dan diimplementasikan berbarengan:
dsl + lua + wasm.

Tier 1 — DSL deklaratif
- Tanpa kode asing. Berupa JSON/YAML yang mendeskripsikan transformasi
  sederhana: mapping, regex replace, konversi unit, rename, dsb.
- Dieksekusi oleh engine bawaan aplikasi.
- Aman, cepat, mudah direview. Cocok untuk kontribusi pemula.

Tier 2 — Lua (source murni, dieksekusi via runtime Lua)
- Plugin berupa source Lua murni (.lua) yang dapat dibaca dan direview.
- Jalur utama plugin komunitas karena transparan dan mudah di-diff.
- 1.0 default memakai `lua_dart` (Lua 5.5.1 via FFI native) dengan capability
  sandbox + batas memori + timeout. Engine WASI (`LuaEngine.wasm`,
  `lua_runtime.wasm` + wasmtime) tersedia sebagai opsi; engine/modul
  dikompilasi sekali per plugin lewat worker persisten + cache runtime
  (`WASM_ENGINE_PLAN.md`).
- Source Lua TIDAK dikompilasi menjadi WASM; source tetap murni.
- Sandbox: stdlib terbatas (tanpa io/package/debug, `os` yang menyentuh host,
  `load` hanya chunk teks), batas waktu dan memori. Tidak ada host function
  net/fs pada 1.0; izin "net"/"file:*" tidak menambah capability runtime.
- Cocok untuk transformer/converter ringan-menengah.

Tier 3 — WASM
- Plugin dikompilasi ke WebAssembly; dieksekusi di runtime WASM dengan
  sandbox ketat (tanpa host function net/fs kecuali diizinkan).
- Untuk performa tinggi dan library berat (kripto, parsing file besar).
- Analisis tetap mungkin via WAT/decompile, tetapi tidak se-transparan Lua.
- Wajib SHA-256 untuk semua; signature Ed25519 wajib untuk registry resmi
  ([REGISTRY.md](REGISTRY.md) §5), opsional untuk sideload.
- Status 1.0: engine WASM (wasmtime) + ABI command WASI v1 sudah tersedia
  (`WasmPluginRuntime`). Libwasmtime hanya dikemas di varian debug Android;
  build release 1.0 belum memuatnya sehingga tier `wasm` memerlukan build
  yang menyertakan engine.
- ABI v1: modul mengekspor `_start`; `argv[0]` nama modul, `argv[1]` id
  operasi, `argv[2]` args JSON; input teks lewat stdin (UTF-8); output teks
  lewat stdout (satu newline akhir dihapus); exit code 0 = sukses, selain itu
  stderr menjadi pesan error. Tidak ada preopen direktori, socket, atau host
  function lain.

## 4. Model Izin (Capabilities)
Izin yang dikenal: "cpu", "net", "file:read", "file:write".
- "cpu" default untuk semua plugin; tidak perlu dialog.
- "net" memerlukan dialog peringatan eksplisit sebelum instalasi:
  "Plugin ini meminta akses internet. Bufferite berjalan offline secara
  default. Setujui hanya jika kamu mempercayai plugin ini."
- "file:read"/"file:write" memerlukan dialog serupa; akses dibatasi ke
  file yang dipilih pengguna (scoped), bukan seluruh filesystem.
- Tanpa izin yang sesuai, panggilan terkait diblokir dan menghasilkan error
  yang jelas (bukan crash). Setiap runtime memanggil `requirePermission(cpu)`
  sebelum eksekusi; DSL/Lua/WASM tidak menyediakan host function net/fs pada
  1.0 sehingga permintaan `net`/`file:*` tidak pernah menjadi capability nyata
  (diuji di `test/core/runtime/permission_matrix_test.dart`).
- Izin tercantum di manifest dan ditampilkan di UI sebelum instalasi.

## 5. Manifest Plugin (plugin.manifest.json)
{
  "manifestVersion": 1,
  "pluginId": "com.contoh.encoding-pack",
  "name": "Encoding Pack",
  "version": "1.2.0",
  "author": "nama/komunitas",
  "description": "Kumpulan operasi encoding tambahan.",
  "license": "MIT",
  "homepage": "https://...",
  "minAppVersion": "1.0.0",
  "tier": "lua",
  "entrypoint": "main.lua",
  "permissions": ["cpu"],
  "operations": [
    {
      "id": "contoh.base32_decode",
      "name": "Base32 Decode",
      "category": "Encode/Decode",
      "params": [
        {
          "key": "padding",
          "label": "Padding",
          "type": "boolean",
          "default": true
        }
      ],
      "inputType": "bytes",
      "outputType": "bytes"
    }
  ],
  "integrity": {
    "sha256": "hash-entrypoint"
  }
}

Signature registry bersifat **detached** (`<paket>.berp.sig`), bukan field
di manifest. Hash di manifest hanya untuk integritas entrypoint; hash paket
`.berp` ada di indeks registry.

## 6. Format Paket (.berp)
- Ekstensi: .berp (BufferitePlugins).
- Isi: file zip berisi plugin.manifest.json, entrypoint sesuai tier, aset
  (jika ada), dan file opsional README/LICENSE.
- Struktur minimum:
  encoding-pack-1.2.0.berp
    plugin.manifest.json
    main.lua            (atau main.wasm / main.json untuk dsl)
    README.md           (opsional)
    LICENSE             (opsional)
- Verifikasi: SHA-256 dari paket .berp dihitung dan dicocokkan dengan hash
  di registry (untuk instalasi via registry) atau dengan hash yang
  disediakan pengguna (untuk sideload). Jika mismatch, instalasi ditolak.
- Batas keamanan MVP: paket maksimum 32 MiB, maksimum 512 entri, satu
  entri maksimum 16 MiB, total isi setelah dekompresi maksimum 64 MiB, dan
  manifest maksimum 512 KiB. Symlink, path traversal, path absolut, dan
  entri duplikat (tanpa memedulikan kapitalisasi) ditolak.
- `plugin.manifest.json` wajib berada di root paket dan `entrypoint` wajib
  ada di dalam paket dengan ekstensi sesuai tier: `.json`/`.yaml`/`.yml`
  untuk DSL, `.lua` untuk Lua, dan `.wasm` untuk WASM.

## 7. Registry (registry.json)

Spesifikasi lengkap ada di [REGISTRY.md](REGISTRY.md). Ringkasan:

- Registry resmi bersifat read-only, statis, dan hanya diakses saat
  pengguna membuka katalog atau menekan "Perbarui"; tidak ada sinkronisasi
  latar belakang.
- `registry.json` berisi satu entri per rilis plugin, dengan `sequence`
  monoton untuk menolak replay indeks lama.
- Setiap indeks dan paket `.berp` memiliki signature Ed25519 terpisah
  (`.sig`); signature wajib untuk registry resmi dan diverifikasi sebelum
  paket dibuka.
- Public key Ed25519 di-pin di aplikasi, bukan diambil dari registry.
- Hash SHA-256 + ukuran paket harus cocok dengan entri; manifest juga harus
  cocok dengan `pluginId`, `version`, `tier`, dan set izin entri.
- Cache indeks disimpan lokal bersama signature; saat offline katalog
  menampilkan cache dengan peringatan.
- Update/rollback mempertahankan maksimal dua versi dan meminta ulang izin
  jika ada izin baru.

## 8. Kurasi & Verifikasi
- Tier DSL: review ringan (skema valid, tidak ada eskalasi).
- Tier Lua: review source WAJIB untuk masuk registry resmi. Fokus review:
  tidak ada upaya akses os/io/net, tidak ada resource abuse, logika benar.
- Tier WASM: SHA-256 WAJIB; signature Ed25519 WAJIB untuk registry resmi
  (F16-T03). Detail di [REGISTRY.md](REGISTRY.md) §5.
- Sideload (instal dari file .berp lokal) didukung penuh, termasuk di MVP,
  untuk memudahkan developer menguji plugin. Plugin sideload ditandai
  "unverified", cukup diverifikasi SHA-256, dan izinnya tetap harus
  disetujui. Sideload tidak pernah dianggap setara dengan plugin registry
  bertanda tangan.
- Semua paket diverifikasi SHA-256 sebelum instalasi. Untuk registry resmi,
  signature paket juga wajib valid. Jika mismatch, instalasi ditolak.

## 9. Kontrak Operasi
Semua operasi (bawaan maupun plugin) mengikuti interface Operation yang
sama (lihat operations.md). Perbedaan hanya pada cara eksekusi di runtime.
Error dari plugin dibungkus dengan pluginId dan stepId agar mudah dilacak.
Operasi plugin yang tidak tersedia (runtime tidak didukung atau plugin
dinonaktifkan) ditandai "unsupported" dan dilewati dengan peringatan saat
recipe dijalankan.

## 10. Integritas Runtime WASM (untuk Tier Lua via WASM)
Konsep:
Plugin Lua tetap berupa source code murni (.lua) yang dapat dibaca dan
direview. Eksekusinya dilakukan oleh interpreter Lua yang telah dikompilasi
ke WebAssembly. File WASM interpreter ini adalah aset aplikasi yang
integritasnya dijamin dengan hash.

Mekanisme:
1. Saat build, file lua_runtime.wasm di-hash (SHA-256) dan hash-nya
   disematkan di aplikasi (hardcoded atau di manifest aplikasi).
2. Saat runtime, sebelum instantiasi, aplikasi membaca byte file WASM dan
   menghitung SHA-256-nya.
3. Jika hash tidak cocok dengan yang di-pin, aplikasi MENOLAK menjalankan
   runtime WASM. Plugin Lua tidak dapat dieksekusi. Tampilkan error yang
   jelas: "Runtime Lua tidak valid. Aplikasi tidak dapat menjalankan plugin
   Lua."
4. Jika hash cocok, runtime diinstansiasi dan source Lua plugin dieksekusi
   di dalam sandbox (batas waktu, memori, tanpa os/io/net kecuali izin).

Status implementasi (CP-063/CP-065): aset `assets/lua_runtime.wasm`
dibundel dengan pin SHA-256 (`luaRuntimeSha256`); `loadLuaWasmModule`
menolak byte yang tidak cocok sebelum engine dibuat. Eksekusi memakai
wasmtime C API di worker isolate persisten (epoch untuk timeout/pembatalan,
batas memori store). Pemilihan engine `wasm` untuk tier `lua` tersedia di
`PluginRuntimeLoader` (`LuaEngine.wasm`) dan bersifat opt-in; default 1.0
tetap `lua_dart` (D11). Cache runtime + worker persisten selesai di
F05-T08/CP-064.

Catatan:
- Yang di-hash adalah file WASM interpreter, BUKAN source Lua plugin.
  Verifikasi source Lua plugin dilakukan lewat kurasi/review (untuk registry
  resmi) atau penandaan "unverified" (sideload).
- Hash runtime di-pin per rilis aplikasi. Jika runtime diperbarui, hash baru
  harus disertakan dalam rilis aplikasi.
- Implementasi Flutter: wasmtime C API via FFI (`lib/core/runtime/wasmtime/`)
  di worker isolate persisten. Engine + modul dikompilasi sekali per plugin;
  store baru per eksekusi. Bukan `wasm_run`.

## 11. Alur Instalasi
A. Instalasi via registry:
1. Pengguna membuka katalog plugin (memerlukan internet; tampilkan
   peringatan akses jaringan).
2. Pengguna memilih plugin; UI menampilkan tier, izin, ukuran, dan sumber.
3. Jika plugin meminta izin selain "cpu", tampilkan dialog peringatan
   eksplisit; pengguna harus menyetujui.
4. Aplikasi mengunduh paket .berp + signature, memverifikasi SHA-256,
   ukuran, dan signature Ed25519 (wajib). Manifest harus cocok dengan entri
   (`pluginId`, `version`, `tier`, izin).
5. Plugin diinstal dan diaktifkan; operasi muncul di Operation Picker.
   Provenance (sumber registry, keyId, hash) disimpan.
6. Pengguna dapat menonaktifkan/menghapus plugin kapan saja dari Settings.
7. Update/rollback mengikuti [REGISTRY.md](REGISTRY.md) §8: maksimal dua
   versi disimpan, izin baru diminta ulang, rollback otomatis bila aktivasi
   versi baru gagal.

B. Instalasi via lokal (sideload):
1. Pengguna memilih file .berp dari penyimpanan.
2. Aplikasi menampilkan pratinjau manifest: tier, izin, ukuran, sumber.
   Plugin ditandai "unverified".
3. Jika plugin meminta izin selain "cpu", tampilkan dialog peringatan
   eksplisit; pengguna harus menyetujui.
4. Aplikasi memverifikasi SHA-256 paket (dihitung lokal) dan mencocokkannya
   dengan hash yang disediakan pengguna atau yang tertanam di manifest.
   Jika mismatch, instalasi ditolak.
5. Plugin diinstal dan diaktifkan; operasi muncul di Operation Picker.

## 12. Sandbox & Batas Resource
- Batas waktu eksekusi per step (misal 2 detik, dapat dikonfigurasi).
- Batas memori per eksekusi plugin.
- Tanpa akses net/fs kecuali izin disetujui.
- Panggilan terlarang menghasilkan error terstruktur, bukan crash.
- Log eksekusi plugin disimpan lokal untuk debugging (opt-in).

## 13. Kebijakan Kompatibilitas
- manifestVersion dan minAppVersion wajib.
- Aplikasi menolak plugin dengan minAppVersion lebih tinggi dari versi app.
- Perubahan kontrak Operation menaikkan versi kontrak; plugin lama ditandai
  "needs update".

## 14. Distribusi & Moderasi
- Spesifikasi registry, signature, update/rollback, dan moderasi ada di
  [REGISTRY.md](REGISTRY.md).
- Registry resmi di-host di GitHub Pages dari repo `bufferite/plugins` pada
  `https://plugins.bufferite.dev`; kontribusi lewat PR dan publikasi dari
  `main` (D12). Scaffold ada di `registry-scaffold/`.
- Kurator awal: pembuat proyek + komunitas open-source GitHub.
- Moderasi: kurator komunitas + maintainer; kriteria: keamanan,
  fungsionalitas, lisensi jelas.
- Plugin yang melanggar kebijakan dihapus dari registry; pengguna yang
  sudah menginstal diberi notifikasi saat membuka katalog.

## 15. Keputusan yang Sudah Dikunci
- Prinsip inti minimal: tidak ada operasi hardcoded di inti; semua operasi
  adalah plugin.
- Bundle core: satu paket core.berp berisi hampir semua operasi CyberChef,
  dibundel sebagai aset dan diinstal otomatis saat first-run.
- Plugin core melewati verifikasi SHA-256 yang sama; hash di-pin di
  aplikasi.
- Format paket: .berp (zip).
- Sideload: didukung di MVP.
- Signature: opsional untuk sideload, wajib untuk registry resmi
  ([REGISTRY.md](REGISTRY.md) §5).
- Kurator awal: pembuat proyek + komunitas open-source GitHub.
- Runtime WASM Flutter: wasmtime C API via FFI, worker isolate persisten;
  `lua_dart` tetap default untuk tier `lua` (D02/D11).
- Tier: dsl + lua + wasm diimplementasikan berbarengan di MVP.

## 16. Pertanyaan Terbuka
- Custody/rotasi kunci Ed25519 (D13) selesai: kunci indeks offline/air-gapped,
  kunci paket di secret CI; detail di [REGISTRY.md](REGISTRY.md) §5.3/§12.
  Hosting/URL registry (D12) sudah selesai.
- Pertanyaan runtime 1.0 sudah ditutup: `lua_dart` default (D02/D11),
  plugin DSL dibungkus `.berp` (D10).
