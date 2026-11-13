import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/operations/utility.dart';
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
  test('case dan title', () async {
    expect(await _run(const UpperCaseOperation(), 'aBc'), 'ABC');
    expect(await _run(const LowerCaseOperation(), 'aBc'), 'abc');
    expect(
      await _run(const TitleCaseOperation(), 'hello WORLD'),
      'Hello World',
    );
  });

  test('reverse', () async {
    expect(await _run(const ReverseOperation(), 'abc'), 'cba');
  });

  test('find & replace', () async {
    expect(
      await _run(const FindReplaceOperation(), 'a-b-c', const <String, Object?>{
        'find': '-',
        'replace': '_',
      }),
      'a_b_c',
    );
    expect(
      () => _run(const FindReplaceOperation(), 'x'),
      throwsA(isA<Object>()),
    );
  });

  test('regex replace + ignore case', () async {
    expect(
      await _run(
        const RegexReplaceOperation(),
        'aXbXc',
        const <String, Object?>{'pattern': 'x', 'ignore_case': true},
      ),
      'abc',
    );
    expect(
      () => _run(const RegexReplaceOperation(), 'x', const <String, Object?>{
        'pattern': '[',
      }),
      throwsA(isA<Object>()),
    );
  });

  test('slice dengan batas aman', () async {
    expect(
      await _run(const SliceOperation(), 'abcdef', const <String, Object?>{
        'start': 2,
        'end': 4,
      }),
      'cd',
    );
    expect(
      await _run(const SliceOperation(), 'abc', const <String, Object?>{
        'start': 99,
      }),
      '',
    );
  });

  test('sort dan unique lines', () async {
    expect(await _run(const SortLinesOperation(), 'b\na\nc'), 'a\nb\nc');
    expect(await _run(const UniqueLinesOperation(), 'a\na\nb'), 'a\nb');
  });
}
