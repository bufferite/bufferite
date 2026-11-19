import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/engine/file_buffer_reader.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bufferite_file_reader_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      await temp.delete(recursive: true);
    }
  });

  test('membaca file secara bertahap menjadi BytesBuffer', () async {
    final bytes = Uint8List.fromList(<int>[
      for (var index = 0; index < 1000; index++) index % 256,
    ]);
    final file = File('${temp.path}/data.bin');
    await file.writeAsBytes(bytes);

    final result = await FileBufferReader(
      memoryLimitBytes: 4096,
      chunkBytes: 7,
    ).materialize(FileBuffer(path: file.path, name: 'data.bin', size: 1000));

    expect(result, isA<BytesBuffer>());
    expect(result.asBytes(), bytes);
  });

  test('menolak file yang melebihi batas memori sebelum membaca', () async {
    final file = File('${temp.path}/besar.bin');
    await file.writeAsBytes(List<int>.filled(32, 1));

    await expectLater(
      FileBufferReader(
        memoryLimitBytes: 16,
      ).materialize(FileBuffer(path: file.path, name: 'besar.bin', size: 32)),
      throwsA(
        isA<AppError>()
            .having((error) => error.code, 'code', 'runtime.file_too_large')
            .having((error) => error.details['size'], 'size', 32)
            .having((error) => error.details['limit'], 'limit', 16),
      ),
    );
  });

  test('file yang hilang menghasilkan error storage', () async {
    await expectLater(
      FileBufferReader(memoryLimitBytes: 1024).materialize(
        FileBuffer(path: '${temp.path}/hilang.bin', name: 'hilang.bin'),
      ),
      throwsA(
        isA<AppError>()
            .having((error) => error.code, 'code', 'runtime.file_read_failed')
            .having(
              (error) => error.category,
              'category',
              ErrorCategory.storage,
            ),
      ),
    );
  });

  test('buffer non-file dikembalikan tanpa salinan', () async {
    final buffer = BytesBuffer(<int>[1, 2, 3]);

    final result = await FileBufferReader(
      memoryLimitBytes: 1024,
    ).materialize(buffer);

    expect(identical(result, buffer), isTrue);
  });
}
