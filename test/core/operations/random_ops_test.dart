import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/operations/random_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('random hex memakai panjang yang diminta', () async {
    final output = await const RandomHexOperation().execute(
      const TextBuffer(''),
      const <String, Object?>{'length': 16},
    );
    final text = output.asText();
    expect(text, hasLength(32));
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(text), isTrue);
  });

  test('random hex unik antar pemanggilan', () async {
    Future<String> run() async => (await const RandomHexOperation().execute(
      const TextBuffer(''),
      const <String, Object?>{'length': 16},
    )).asText();
    final values = <String>{for (var i = 0; i < 8; i++) await run()};
    expect(values, hasLength(8));
  });

  test('random bytes sesuai panjang', () async {
    final output = await const RandomBytesOperation().execute(
      const TextBuffer(''),
      const <String, Object?>{'length': 8},
    );
    expect(output.asText().length, 8);
  });

  test('menolak panjang tidak valid', () async {
    expect(
      () => const RandomHexOperation().execute(
        const TextBuffer(''),
        const <String, Object?>{'length': 0},
      ),
      throwsA(isA<Object>()),
    );
  });
}
