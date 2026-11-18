# DSL Plugin (D08)

Skema `transform.json` untuk plugin tier `dsl`. Versi saat ini: **1**.

## Bentuk

```json
{
  "version": 1,
  "description": "opsional",
  "steps": [
    { "op": "map", "mapping": { "kucing": "cat" } },
    { "op": "regex_replace", "pattern": "\\d+", "replacement": "#" },
    { "op": "convert_unit", "from": "km", "to": "m" },
    { "op": "rename", "mapping": { "nama": "name" } }
  ]
}
```

Input dan output selalu teks UTF-8. Step dijalankan berurutan; output step
menjadi input step berikutnya.

## Step

| op | Field | perilaku |
|---|---|---|
| `map` | `mapping` (objek string→string, wajib), `all` (bool, default `true`) | ganti substring literal |
| `regex_replace` | `pattern` (wajib), `replacement` (default `""`), `ignore_case` (default `false`), `all` (default `true`) | regex via `SafeRegex` |
| `convert_unit` | `from`, `to` (wajib) | konversi angka + satuan |
| `rename` | `mapping` (wajib) | ganti nama key objek JSON, rekursif |

Satuan didukung:

- panjang: `m`, `km`, `cm`, `mm`, `mi`, `yd`, `ft`, `in`
- massa: `kg`, `g`, `mg`, `t`, `lb`, `oz`
- data: `b`, `kb`, `mb`, `gb`, `tb`, `kib`, `mib`, `gib`
- waktu: `s`, `ms`, `min`, `h`, `day`
- suhu: `c`, `f`, `k`

Input `convert_unit` berupa angka dengan satuan opsional (`2.5 km`, `100`).
Jika satuan tidak ditulis, nilai dianggap memakai satuan `from`.

## Batas keamanan

- Maksimum 200 step.
- `pattern` maksimum 512 karakter; kuantifier bersarang (heuristik ReDoS)
  ditolak; input maksimum 1 MiB karakter.
- Hanya izin `cpu`. Tidak ada akses jaringan/filesystem, tidak ada `eval`,
  loop, variabel, atau kode asing.
- Field tak dikenal ditolak (typo = error, bukan diam-diam diabaikan).
- Batas waktu ditegakkan host isolate (F03-T04); pembatalan diperiksa
  antar step.

## Error

| code | kapan |
|---|---|
| `plugin.dsl_invalid` | JSON/skema salah, versi tak didukung, op/field tak dikenal |
| `operation.invalid_input` | input tidak cocok (JSON bukan objek, satuan campur, angka invalid) |
| `operation.cancelled` | token dibatalkan sebelum/selama eksekusi |
| `runtime.file_not_materialized` | input masih `FileBuffer` |

## Di luar cakupan (YAGNI)

Percabangan, loop, variabel, fungsi, dan modul. Tambahkan hanya jika ada
plugin nyata yang membutuhkannya.