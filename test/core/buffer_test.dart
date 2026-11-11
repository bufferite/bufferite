import 'dart:convert';
import 'dart:typed_data';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextBuffer', () {
    test('menghitung panjang dalam byte, bukan karakter', () {
      expect(const TextBuffer('é').length, 2);
      expect(const TextBuffer('hello').length, 5);
    });

    test('mendukung encoding selain UTF-8', () {
      const buffer = TextBuffer('é', encoding: latin1);

      expect(buffer.asBytes(), Uint8List.fromList(<int>[0xE9]));
      expect(const TextBuffer('é') == buffer, isFalse);
    });

    test('preview memotong teks', () {
      const buffer = TextBuffer('hello');

      expect(buffer.preview(maxBytes: 3), const TextBuffer('hel'));
      expect(identical(buffer.preview(maxBytes: 10), buffer), isTrue);
    });

    test('preview menolak batas tidak valid', () {
      const buffer = TextBuffer('hello');

      expect(() => buffer.preview(maxBytes: 0), throwsA(isA<ArgumentError>()));
    });
  });

  group('BytesBuffer', () {
    test('tidak memutasi sumber dan menyalin hasil', () {
      final source = <int>[1, 2, 3];
      final buffer = BytesBuffer(source);
      source[0] = 99;

      final firstRead = buffer.asBytes();
      firstRead[1] = 88;

      expect(buffer.asBytes(), Uint8List.fromList(<int>[1, 2, 3]));
    });

    test('mendekode teks dan membungkus byte tidak valid', () {
      expect(BytesBuffer(utf8.encode('hello')).asText(), 'hello');

      expect(
        () => BytesBuffer(<int>[0xFF]).asText(),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'buffer.decode_failed',
          ),
        ),
      );
    });

    test('preview memotong byte dan menjaga isi asli', () {
      final buffer = BytesBuffer(<int>[0, 1, 2, 3, 4, 5]);

      expect(buffer.preview(maxBytes: 3), BytesBuffer(<int>[0, 1, 2]));
      expect(buffer.length, 6);
      expect(identical(buffer.preview(maxBytes: 10), buffer), isTrue);
    });

    test('equality membandingkan isi', () {
      expect(BytesBuffer(<int>[1, 2]) == BytesBuffer(<int>[1, 2]), isTrue);
      expect(BytesBuffer(<int>[1, 2]) == BytesBuffer(<int>[1, 3]), isFalse);
    });
  });

  group('FileBuffer', () {
    const file = FileBuffer(path: '/tmp/a.bin', name: 'a.bin', size: 42);

    test('menggunakan ukuran yang diketahui', () {
      expect(file.length, 42);
      expect(const FileBuffer(path: '/tmp/b.bin', name: 'b.bin').length, 0);
    });

    test('harus dimaterialisasi sebelum dibaca', () {
      expect(() => file.asBytes(), throwsA(isA<UnsupportedError>()));
      expect(() => file.asText(), throwsA(isA<UnsupportedError>()));
    });

    test('preview mengembalikan referensi yang sama', () {
      expect(identical(file.preview(), file), isTrue);
    });
  });

  group('Buffer JSON', () {
    test('round-trip text, bytes, dan file', () {
      final buffers = <Buffer>[
        const TextBuffer('hello'),
        const TextBuffer('é', encoding: latin1),
        BytesBuffer(<int>[0, 1, 2, 255]),
        const FileBuffer(path: '/tmp/a.bin', name: 'a.bin', size: 10),
      ];

      for (final buffer in buffers) {
        expect(Buffer.fromJson(buffer.toJson()), buffer);
      }
    });

    test('menolak JSON tidak valid', () {
      final invalid = <Map<String, Object?>>[
        <String, Object?>{'value': 'x'},
        <String, Object?>{'type': 1},
        <String, Object?>{'type': 'unknown'},
        <String, Object?>{'type': 'text', 'value': 1},
        <String, Object?>{'type': 'text', 'value': 'x', 'encoding': 'nope'},
        <String, Object?>{'type': 'bytes', 'base64': '%%%'},
        <String, Object?>{'type': 'file', 'path': '/tmp/a'},
        <String, Object?>{
          'type': 'file',
          'path': '/tmp/a',
          'name': 'a',
          'size': 'big',
        },
      ];

      for (final json in invalid) {
        expect(
          () => Buffer.fromJson(json),
          throwsA(isA<AppError>()),
          reason: '$json',
        );
      }
    });
  });
}
