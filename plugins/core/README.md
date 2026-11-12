# core.berp — Authoring Spesifikasi (F13-T01)

Panduan menulis operasi core Bufferite yang dibundel sebagai `core.berp`.

## 1. Struktur source

```
plugins/core/
  README.md                  (dokumen ini)
  src/
    <kategori>/<operasi>/    satu folder per operasi
      operation.dart         implementasi Operation (Dart, engine bawaan)
      test_vectors.json      kasus sukses + error (schema `operations.md` §9)
  manifest/
    core.manifest.json       manifest paket core
```

- Satu operasi = satu folder, satu `operationId` stabil.
- `operationId` memakai format `core.<snake_case>` (mis. `core.base64_decode`).
- ID **tidak boleh berubah** setelah rilis; perubahan perilaku menaikkan
  versi paket, bukan ID.

## 2. Manifest paket

Manifest mengikuti `PLUGINS.md` (manifestVersion 1). Contoh:

```json
{
  "manifestVersion": 1,
  "pluginId": "dev.bufferite.core",
  "name": "Bufferite Core",
  "version": "1.0.0",
  "minAppVersion": "1.0.0",
  "tier": "dsl",
  "entrypoint": "operations.json",
  "permissions": ["cpu"],
  "operations": [
    {
      "id": "core.base64_decode",
      "name": "Base64 Decode",
      "category": "Encode/Decode",
      "params": [],
      "inputType": "text",
      "outputType": "bytes"
    }
  ]
}
```

## 3. Format runtime tier

- **dsl**: operasi dideklarasikan di `operations.json` dan dijalankan engine
  bawaan. Tidak ada kode asing. Regex wajib aman (timeout, lihat F14-T04).
- **lua**: entrypoint `.lua` mendefinisikan `transform(input, args)`.
  stdlib tanpa `os`, `io`, `package`, `debug`; net/fs hanya lewat izin.
- **wasm**: entrypoint `.wasm` (mis. `lua_runtime.wasm`) dengan host API
  terbatas. Hash WASM di-pin di aplikasi.

## 4. Aturan ID dan versi

- `pluginId`: reverse-DNS huruf kecil (`dev.bufferite.core`).
- `operationId`: stabil, unik secara global, snake_case setelah prefix.
- Perubahan breaking pada operasi: naikkan `version` paket dan dokumentasikan
  di `operations.md`; jangan ubah ID.
- Operasi baru boleh ditambah tanpa menaikkan `minAppVersion` bila kontrak
  tetap kompatibel.

## 5. Test vector wajib

Setiap operasi menyertakan minimal satu kasus sukses dan satu edge/error di
`test_vectors.json`, mengikuti skema `operations.md` §9. Test dijalankan
terhadap `core.berp` hasil build (bukan implementasi tiruan).

## 6. Lisensi/atribusi

Operasi yang diadaptasi dari sumber lain wajib mencatat sumber, lisensi, dan
atribusi di manifest/README (F13-T10).
