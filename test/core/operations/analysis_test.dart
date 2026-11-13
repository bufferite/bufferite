import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/operations/analysis.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _run(
  Operation operation,
  String input, [
  Map<String, Object?> args = const <String, Object?>{},
]) async {
  final output = await operation.execute(TextBuffer(input), args);
  return output.asText();
}

void main() {
  test('entropy menaik untuk data acak', () async {
    final low = await _run(const EntropyOperation(), 'aaaaaaaa');
    final high = await _run(
      const EntropyOperation(),
      String.fromCharCodes(List<int>.generate(64, (i) => i)),
    );
    expect(low, contains('0.0000'));
    expect(high, contains('bit/byte'));
  });

  test('frekuensi mengurutkan byte terbanyak', () async {
    final output = await _run(const FrequencyOperation(), 'aab');
    expect(output.split('\n').first, '61  2');
  });

  test('file type mendeteksi PDF', () async {
    expect(await _run(const FileTypeOperation(), '%PDF-1.4'), 'PDF');
    expect(await _run(const FileTypeOperation(), 'hello'), 'Tidak dikenal');
  });

  test('strings mengekstrak teks printable', () async {
    final output = await _run(const StringsOperation(), 'abc\x00hello\x00xy');
    expect(output, 'hello');
  });

  test('strings menghormati min_length', () async {
    final output = await _run(
      const StringsOperation(),
      'abc\x00hello',
      const <String, Object?>{'min_length': 4},
    );
    expect(output, 'hello');
  });
}
