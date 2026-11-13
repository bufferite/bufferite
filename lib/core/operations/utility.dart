import '../engine/buffer.dart';
import '../error/app_error.dart';
import '../plugin/operation.dart';
import '../plugin/operation_param.dart';
import 'safe_regex.dart';

/// Operasi Utility untuk `core.berp` (F13-T08).
const OperationIO _textToText = OperationIO(
  input: BufferKind.text,
  output: BufferKind.text,
);

/// Batas praktis untuk pola regex agar tidak membahayakan (lihat F14-T04).
const int maxRegexPatternLength = 512;

AppError _invalid(String message) {
  return AppError(
    category: ErrorCategory.validation,
    code: 'operation.invalid_input',
    message: message,
  );
}

final class UpperCaseOperation implements Operation {
  const UpperCaseOperation();
  @override
  String get id => 'core.upper_case';
  @override
  String get name => 'Upper Case';
  @override
  OperationCategory get category => OperationCategory.utility;
  @override
  List<OperationParam> get params => const <OperationParam>[];
  @override
  OperationIO get io => _textToText;
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async =>
      TextBuffer(input.asText().toUpperCase());
}

final class LowerCaseOperation implements Operation {
  const LowerCaseOperation();
  @override
  String get id => 'core.lower_case';
  @override
  String get name => 'Lower Case';
  @override
  OperationCategory get category => OperationCategory.utility;
  @override
  List<OperationParam> get params => const <OperationParam>[];
  @override
  OperationIO get io => _textToText;
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async =>
      TextBuffer(input.asText().toLowerCase());
}

final class TitleCaseOperation implements Operation {
  const TitleCaseOperation();
  @override
  String get id => 'core.title_case';
  @override
  String get name => 'Title Case';
  @override
  OperationCategory get category => OperationCategory.utility;
  @override
  List<OperationParam> get params => const <OperationParam>[];
  @override
  OperationIO get io => _textToText;
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final words = input.asText().split(' ');
    return TextBuffer(
      words
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
          )
          .join(' '),
    );
  }
}

final class ReverseOperation implements Operation {
  const ReverseOperation();
  @override
  String get id => 'core.reverse';
  @override
  String get name => 'Reverse';
  @override
  OperationCategory get category => OperationCategory.utility;
  @override
  List<OperationParam> get params => const <OperationParam>[];
  @override
  OperationIO get io => _textToText;
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async =>
      TextBuffer(input.asText().split('').reversed.join());
}

final class FindReplaceOperation implements Operation {
  const FindReplaceOperation();
  @override
  String get id => 'core.find_replace';
  @override
  String get name => 'Find & Replace';
  @override
  OperationCategory get category => OperationCategory.utility;
  @override
  List<OperationParam> get params => const <OperationParam>[
    OperationParam(
      key: 'find',
      label: 'Cari',
      type: OperationParamType.string,
      isRequired: true,
    ),
    OperationParam(
      key: 'replace',
      label: 'Ganti',
      type: OperationParamType.string,
      defaultValue: '',
    ),
  ];
  @override
  OperationIO get io => _textToText;
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final find = args['find'];
    if (find is! String || find.isEmpty) {
      throw _invalid('Parameter "find" wajib diisi.');
    }
    final replace = args['replace'] is String ? args['replace']! as String : '';
    return TextBuffer(input.asText().replaceAll(find, replace));
  }
}

final class RegexReplaceOperation implements Operation {
  const RegexReplaceOperation();
  @override
  String get id => 'core.regex_replace';
  @override
  String get name => 'Regex Replace';
  @override
  OperationCategory get category => OperationCategory.utility;
  @override
  List<OperationParam> get params => const <OperationParam>[
    OperationParam(
      key: 'pattern',
      label: 'Pola',
      type: OperationParamType.string,
      isRequired: true,
    ),
    OperationParam(
      key: 'replacement',
      label: 'Ganti',
      type: OperationParamType.string,
      defaultValue: '',
    ),
    OperationParam(
      key: 'ignore_case',
      label: 'Abaikan huruf besar/kecil',
      type: OperationParamType.boolean,
      defaultValue: false,
    ),
  ];
  @override
  OperationIO get io => _textToText;
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final pattern = args['pattern'];
    if (pattern is! String || pattern.isEmpty) {
      throw _invalid('Parameter "pattern" wajib diisi.');
    }
    if (pattern.length > maxRegexPatternLength) {
      throw _invalid('Pola melebihi batas $maxRegexPatternLength karakter.');
    }
    final replacement = args['replacement'] is String
        ? args['replacement']! as String
        : '';
    final ignoreCase = args['ignore_case'] == true;
    return TextBuffer(
      SafeRegex.replaceAll(
        input.asText(),
        pattern: pattern,
        replacement: replacement,
        ignoreCase: ignoreCase,
      ),
    );
  }
}

final class SliceOperation implements Operation {
  const SliceOperation();
  @override
  String get id => 'core.slice';
  @override
  String get name => 'Slice';
  @override
  OperationCategory get category => OperationCategory.utility;
  @override
  List<OperationParam> get params => const <OperationParam>[
    OperationParam(
      key: 'start',
      label: 'Mulai',
      type: OperationParamType.integer,
      defaultValue: 0,
      min: 0,
    ),
    OperationParam(
      key: 'end',
      label: 'Selesai (opsional)',
      type: OperationParamType.integer,
      min: 0,
    ),
  ];
  @override
  OperationIO get io => _textToText;
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final text = input.asText();
    final start = args['start'] is int ? args['start']! as int : 0;
    final end = args['end'] is int ? args['end']! as int : text.length;
    final from = start.clamp(0, text.length);
    final to = end.clamp(from, text.length);
    return TextBuffer(text.substring(from, to));
  }
}

final class SortLinesOperation implements Operation {
  const SortLinesOperation();
  @override
  String get id => 'core.sort_lines';
  @override
  String get name => 'Sort Lines';
  @override
  OperationCategory get category => OperationCategory.utility;
  @override
  List<OperationParam> get params => const <OperationParam>[];
  @override
  OperationIO get io => _textToText;
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final lines = input.asText().split('\n')..sort();
    return TextBuffer(lines.join('\n'));
  }
}

final class UniqueLinesOperation implements Operation {
  const UniqueLinesOperation();
  @override
  String get id => 'core.unique_lines';
  @override
  String get name => 'Unique Lines';
  @override
  OperationCategory get category => OperationCategory.utility;
  @override
  List<OperationParam> get params => const <OperationParam>[];
  @override
  OperationIO get io => _textToText;
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final seen = <String>{};
    final result = <String>[];
    for (final line in input.asText().split('\n')) {
      if (seen.add(line)) {
        result.add(line);
      }
    }
    return TextBuffer(result.join('\n'));
  }
}
