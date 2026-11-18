# operations.md — Bufferite Operation & Recipe Contract

Versi dokumen: 1.0
Versi kontrak Operation: 1
Status: Final (MVP)

## 1. Tujuan

Dokumen ini mendefinisikan kontrak yang sama untuk semua operasi—core maupun
komunitas—serta format recipe yang disimpan, diimpor, dan diekspor aplikasi.
Perubahan pada kontrak Operation atau skema recipe wajib menaikkan versi dan
memperbarui dokumen ini beserta test kontrak.

Prioritas dokumen mengikuti `AGENT.md`: `ARCHITECTURE.md` > `PLUGINS.md` >
`operations.md` > `DESIGN.md` > `ROADMAP.md`.

## 2. Prinsip

- Semua operasi adalah plugin; tidak ada operasi hardcoded di inti.
- Satu kontrak untuk DSL, Lua via WASM, dan WASM.
- Operasi menerima satu `Buffer` dan argumen tervalidasi, lalu mengembalikan
  satu `Buffer` baru (immutable).
- Operasi tidak boleh melakukan efek samping di luar izin plugin.
- Error operasi dibungkus dengan konteks `pluginId` dan `stepId`.
- Operasi yang tidak tersedia ditandai `unsupported` dan dilewati dengan
  peringatan; aplikasi tidak crash.

## 3. Model Buffer

Buffer adalah nilai immutable dengan tiga varian:

| Varian | Isi | Catatan |
|---|---|---|
| `text` | String + encoding | Default UTF-8; teks disimpan apa adanya |
| `bytes` | `Uint8List` | Sumber utama transformasi biner |
| `file` | Referensi file scoped | Hanya untuk input pengguna; tidak diserialisasi ke `.brecipe` v1 |

Kontrak minimum:

```dart
sealed class Buffer {
  BufferKind get kind;
  int get length;

  Uint8List asBytes();
  String asText({Encoding encoding = utf8});
  Buffer preview({int maxBytes = 4096});
}
```

Aturan:

- `asBytes()` pada `text` memakai encoding yang ditentukan (default UTF-8).
- `asText()` pada `bytes` memakai encoding yang ditentukan; byte tidak valid
  menghasilkan error `buffer.decode_failed`, bukan exception mentah.
- `file` dibaca hanya setelah izin `file:read` disetujui dan dibatasi pada
  file yang dipilih pengguna.
- Preview tidak boleh memuat seluruh file besar; implementasi wajib memotong
  pada `maxBytes`.
- Operasi tidak boleh memutasi buffer input.

Representasi JSON Buffer (dipakai recipe dan pesan isolate):

```json
{ "type": "text", "value": "SGVsbG8=" }
```

```json
{ "type": "bytes", "base64": "SGVsbG8=" }
```

```json
{ "type": "file", "path": "/scoped/path", "name": "input.bin", "size": 1024 }
```

`file` hanya valid di runtime, bukan di file `.brecipe` v1.

## 4. Parameter Operasi

```dart
enum OperationParamType { string, integer, boolean, select }

final class OperationParam {
  final String key;
  final String label;
  final OperationParamType type;
  final Object? defaultValue;
  final bool required;
  final List<OperationParamOption> options;
  final int? min;
  final int? max;
  final bool multiline;
  final bool secret;
  final String? helpText;
}
```

Aturan validasi:

- `key` unik dalam satu operasi, format `snake_case`.
- `required=true` berarti nilai wajib ada setelah default diterapkan.
- `select` wajib memiliki minimal satu opsi; nilai harus salah satu opsi.
- `integer` wajib menghormati `min`/`max` bila diisi.
- `secret=true` tidak boleh ditampilkan di log dan UI harus menutupi nilai.
- Argumen yang tidak dikenal ditolak dengan `operation.param_unknown`.
- Nilai default diterapkan sebelum operasi dieksekusi.

## 5. Kontrak Operation

```dart
const int operationContractVersion = 1;

enum OperationCategory {
  encodeDecode,
  crypto,
  format,
  analysis,
  utility,
}

abstract interface class Operation {
  String get id;                    // stabil, contoh: core.base64_decode
  String get name;                  // label UI
  OperationCategory get category;
  List<OperationParam> get params;
  OperationIO get io;

  Future<Buffer> execute(Buffer input, Map<String, Object?> args);
}

final class OperationIO {
  final BufferKind input;
  final BufferKind output;
}

final class OperationDescriptor {
  final String id;
  final String name;
  final OperationCategory category;
  final List<OperationParam> params;
  final OperationIO io;
  final String pluginId;
  final String pluginVersion;
  final RuntimeTier tier;
  final int contractVersion;
}
```

Aturan ID:

- Format yang disarankan: `<namespace>.<nama_operasi>` (contoh
  `core.base64_decode`).
- ID tidak boleh berubah setelah dipublikasikan; perubahan perilaku
  memerlukan ID baru atau versi plugin baru.
- ID duplikat antar-plugin ditolak saat registrasi; operasi pertama yang
  terdaftar dipertahankan dan konflik dicatat sebagai peringatan.

## 6. Kontrak Eksekusi

Urutan eksekusi pipeline:

```text
Input Buffer
  -> step 1 (jika enabled dan supported)
  -> step 2
  -> ...
  -> Output Buffer
```

Semantik:

1. Step dengan `enabled=false` dilewati tanpa error.
2. Step dengan operasi `unsupported` dilewati dengan peringatan
   `operation.unsupported`. Penyebab: plugin nonaktif, tier tidak tersedia,
   contract version tidak kompatibel, atau runtime gagal diverifikasi.
3. Setiap operasi menerima salinan argumen yang sudah divalidasi dan buffer
   input immutable.
4. Eksekusi berjalan di isolate; UI menerima event progres dan hasil secara
   streaming.
5. Error pada satu step tidak boleh membuat UI crash.
6. Kebijakan default MVP: **hentikan pipeline** pada error pertama dan
   kembalikan output terakhir yang valid beserta detail error step. Perilaku
   ini masih menunggu keputusan D06; engine wajib siap mendukung mode
   "lanjutkan" tanpa perubahan kontrak.
7. Pembatalan pengguna menghasilkan `cancelled`, bukan error runtime.
8. Batas waktu dan memori per step ditegakkan sandbox.

Status implementasi engine:

- `PipelineExecutor` sudah menjalankan step sekuensial, skip disabled/
  unsupported, timeout per step, pembatalan best-effort, dan stream event.
- Dua kebijakan error tersedia: `stop` (default) dan
  `continueWithLastOutput`; keputusan final tetap menunggu D06.
- Eksekusi masih berjalan di isolate pemanggil. Host isolate pekerja
  (request/response/progress) belum diaktifkan karena menunggu runtime
  plugin F05; timeout saat ini tidak dapat menghentikan paksa operasi yang
  sudah berjalan. Task terkait: F03-T04.
- Pembersihan isolate dan enforcement memori mengikuti host isolate di
  F05.

## 7. Error Terstruktur

Semua error yang menyeberang batas runtime memakai bentuk berikut:

```json
{
  "category": "runtime",
  "code": "runtime.timeout",
  "message": "Operasi melewati batas waktu 2 detik.",
  "pluginId": "com.contoh.encoding-pack",
  "stepId": "step-1",
  "details": { "timeoutMs": 2000 }
}
```

Kategori:

| Category | Contoh kode |
|---|---|
| `validation` | `recipe.invalid`, `operation.param_invalid` |
| `plugin` | `plugin.manifest_invalid`, `plugin.verify_failed` |
| `runtime` | `runtime.timeout`, `runtime.memory_limit`, `runtime.trap` |
| `permission` | `permission.denied` |
| `storage` | `storage.read_failed`, `storage.write_failed` |
| `unsupported` | `operation.unsupported` |
| `cancelled` | `operation.cancelled` |

Aturan:

- `code` stabil dan dapat diuji; `message` boleh berubah dan berbahasa
  Indonesia untuk UI.
- `pluginId` dan `stepId` wajib diisi bila error berasal dari eksekusi step.
- `details` hanya memuat data non-sensitif.
- Exception mentah dari plugin tidak boleh bocor ke UI; runtime membungkusnya.

## 8. Skema Recipe v1

File recipe menggunakan ekstensi `.brecipe` dan berisi JSON UTF-8.

```json
{
  "schemaVersion": 1,
  "id": "4f1c2b7e-7d1a-4a3e-9f10-2c6b8f7a1d22",
  "name": "Base64 lalu Hex",
  "steps": [
    {
      "id": "step-1",
      "operationId": "core.base64_decode",
      "args": {},
      "enabled": true
    },
    {
      "id": "step-2",
      "operationId": "core.hex_encode",
      "args": { "uppercase": true },
      "enabled": true
    }
  ],
  "input": { "type": "text", "value": "SGVsbG8=" },
  "output": null,
  "meta": {
    "createdAt": "2026-11-11T08:00:00Z",
    "updatedAt": "2026-11-11T08:05:00Z",
    "appVersion": "1.0.0"
  }
}
```

Field:

| Field | Wajib | Aturan |
|---|---|---|
| `schemaVersion` | Ya | Integer; versi yang didukung aplikasi saat ini = `1` |
| `id` | Ya | UUID v4, unik per recipe |
| `name` | Ya | 1–120 karakter setelah trim |
| `steps` | Ya | 1–200 step; urutan array = urutan eksekusi |
| `steps[].id` | Ya | Unik dalam recipe; stabil selama edit |
| `steps[].operationId` | Ya | ID operasi yang terdaftar atau `unsupported` |
| `steps[].args` | Ya | Objek; divalidasi terhadap schema operasi |
| `steps[].enabled` | Tidak | Default `true` |
| `input` | Ya | Buffer JSON tipe `text` atau `bytes` |
| `output` | Tidak | Cache hasil terakhir; tidak dipercaya saat impor |
| `meta` | Tidak | Metadata; field tak dikenal diabaikan |
| `meta.createdAt` | Tidak | ISO-8601 UTC |
| `meta.updatedAt` | Tidak | ISO-8601 UTC |
| `meta.appVersion` | Tidak | Versi aplikasi saat disimpan |

Aturan impor:

- `schemaVersion > 1` ditolak dengan `recipe.schema_unsupported`.
- Field wajib yang hilang atau bertipe salah ditolak dengan
  `recipe.invalid` dan pesan field yang jelas.
- `steps[].id` duplikat ditolak.
- Input `file` ditolak di `.brecipe` v1 dengan `recipe.file_input_unsupported`.
- Ukuran file maksimum 5 MiB; jumlah step maksimum 200.
- `output` diabaikan dan dihitung ulang; exporter menulis `null`.
- Operasi yang tidak dikenal tetap disimpan agar recipe bisa dibuka, lalu
  ditandai `unsupported` saat dijalankan.

Aturan ekspor:

- Menulis JSON UTF-8 dengan `schemaVersion` saat ini.
- Menulis `output: null`.
- Tidak menyertakan path file lokal atau data sensitif lain di luar `input`.
- Nama file default: `<nama-recipe-slug>.brecipe`.

Versi skema:

- Perubahan yang tidak kompatibel menaikkan `schemaVersion`.
- Penambahan field opsional yang kompatibel boleh tanpa kenaikan versi,
  tetapi harus didokumentasikan di sini.
- Migrasi berjalan berurutan dari versi lama ke versi terbaru; recipe dengan
  versi lebih baru dari aplikasi ditolak, bukan ditebak.

## 9. Contract Test

Setiap operasi core wajib memiliki test vector dengan bentuk:

```json
{
  "operationId": "core.base64_decode",
  "input": { "type": "text", "value": "SGVsbG8=" },
  "args": {},
  "expect": { "type": "text", "value": "Hello" }
}
```

Kasus error memakai:

```json
{
  "operationId": "core.base64_decode",
  "input": { "type": "text", "value": "%%%" },
  "args": {},
  "expectError": { "code": "operation.invalid_input" }
}
```

Aturan:

- Minimal satu kasus sukses dan satu kasus edge/error per operasi.
- Test vector core disimpan di repo aplikasi dan dijalankan terhadap
  `core.berp` hasil build, bukan terhadap implementasi tiruan.
- Test memverifikasi output byte-per-byte untuk operasi biner dan teks untuk
  operasi teks.
- Test juga memverifikasi bahwa operasi tidak memutasi input.
- Plugin komunitas tidak wajib menyertakan test vector di paket; kurasi
  registry dapat memintanya saat review.

## 10. Tier Runtime dan Izin

| Tier | Eksekusi | Batasan |
|---|---|---|
| `dsl` | Engine bawaan | Tanpa kode asing; regex dengan timeout |
| `lua` | Interpreter Lua via WASM (`wasm_run`) | Tanpa `os`, `io`, `package`, `debug`; tanpa net/fs kecuali izin |
| `wasm` | Runtime WASM | Tanpa host function net/fs kecuali izin |

Semua tier tunduk pada:

- hash runtime dan paket yang di-pin,
- batas waktu dan memori,
- model izin `cpu`, `net`, `file:read`, `file:write`,
- error terstruktur dan pembungkusan `pluginId`/`stepId`.

Kontrak implementasi sandbox MVP:

- `SandboxConfig` default: timeout 2 detik per operasi, batas memori 64 MiB,
  izin `cpu`; `cpu` selalu aktif.
- `SandboxContext` membawa `pluginId`, `operationId`, `stepId`, config, dan
  token pembatalan. Runtime wajib memanggil `ensureActive()` dan
  `requirePermission()` sebelum side effect.
- `SandboxRuntime` adalah antarmuka bersama untuk runtime DSL, Lua, dan WASM.
- Enforcement timeout/memori dan pembersihan isolate tetap menunggu host
  isolate F05-T04.

## 11. Katalog core.berp (Rencana MVP)

Katalog final menunggu keputusan D01 dan diselesaikan bertahap di F13. Daftar
ini menjadi acuan awal; setiap operasi wajib memiliki manifest, contoh I/O,
test kontrak, dan entri dokumentasi sebelum dianggap selesai.

| Kategori | Operasi P0 | Tier awal |
|---|---|---|
| Encode/Decode | Base64 encode/decode, Base32 encode/decode, Hex encode/decode, URL encode/decode, HTML entity encode/decode | `lua`/`dsl` |
| Crypto | MD5, SHA-1, SHA-256, SHA-512, HMAC-SHA1/256/512, AES-CBC/CTR, XOR | `lua`/`wasm` |
| Format | JSON prettify/minify, JWT decode (tanpa verifikasi), XML prettify | `lua`/`dsl` |
| Analysis | Entropy, frequency, magic bytes, string extraction | `lua`/`wasm` |
| Utility | Case conversion, reverse, find & replace, regex replace, slice, sort lines, unique lines | `dsl`/`lua` |

Catatan keamanan:

- MD5 dan SHA-1 hanya untuk kompatibilitas; UI wajib memberi label bahwa
  keduanya bukan untuk keamanan.
- Operasi acak wajib memakai CSPRNG.
- Operasi regex wajib memiliki batas waktu dan panjang input.
- AES hanya CBC/CTR (tanpa autentikasi); ECB tidak disediakan. Detail dan
  risiko diterima ada di `SECURITY_REVIEW_CRYPTO.md`.
- XOR adalah obfuscation, bukan enkripsi.

## 12. Kompatibilitas

- `operationContractVersion` saat ini `1`.
- Plugin dengan `contractVersion` lebih tinggi ditandai `needs update` dan
  operasinya `unsupported`, bukan crash.
- Perubahan kontrak wajib menaikkan versi kontrak, memperbarui dokumen ini,
  dan menambah test migrasi/kompatibilitas.
- Perubahan skema recipe wajib menaikkan `schemaVersion`, menambah migrasi,
  dan memperbarui `ARCHITECTURE.md`.

## 13. Pertanyaan Terbuka

- D06: kebijakan final stop vs lanjut saat error step.
- D08: detail skema DSL.
- Batas ukuran input/output MVP dan strategi streaming file besar.
- Apakah operasi core perlu metadata contoh I/O di manifest, atau cukup di
  test vector repo.
