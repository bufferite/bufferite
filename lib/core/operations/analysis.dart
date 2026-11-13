import 'dart:convert';
import 'dart:math' as math;

import '../engine/buffer.dart';
import '../plugin/operation.dart';
import '../plugin/operation_param.dart';

/// Operasi Analysis untuk `core.berp` (F13-T07).
const OperationIO _textToText = OperationIO(
  input: BufferKind.text,
  output: BufferKind.text,
);

final class EntropyOperation implements Operation {
  const EntropyOperation();

  @override
  String get id => 'core.entropy';

  @override
  String get name => 'Entropy';

  @override
  OperationCategory get category => OperationCategory.analysis;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final bytes = utf8.encode(input.asText());
    if (bytes.isEmpty) {
      return const TextBuffer('Shannon entropy: 0.0 bit/byte');
    }
    final counts = List<int>.filled(256, 0);
    for (final byte in bytes) {
      counts[byte]++;
    }
    var entropy = 0.0;
    for (final count in counts) {
      if (count == 0) {
        continue;
      }
      final probability = count / bytes.length;
      entropy -= probability * (math.log(probability) / math.ln2);
    }
    return TextBuffer(
      'Shannon entropy: ${entropy.toStringAsFixed(4)} bit/byte',
    );
  }
}

final class FrequencyOperation implements Operation {
  const FrequencyOperation();

  @override
  String get id => 'core.frequency';

  @override
  String get name => 'Byte Frequency';

  @override
  OperationCategory get category => OperationCategory.analysis;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final bytes = utf8.encode(input.asText());
    final counts = <int, int>{};
    for (final byte in bytes) {
      counts[byte] = (counts[byte] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final buffer = StringBuffer();
    for (final entry in entries) {
      buffer.writeln(
        '${entry.key.toRadixString(16).padLeft(2, '0')}  ${entry.value}',
      );
    }
    return TextBuffer(buffer.toString().trimRight());
  }
}

final class FileTypeOperation implements Operation {
  const FileTypeOperation();

  static const List<(String, List<int>)> _signatures = <(String, List<int>)>[
    ('PNG', <int>[0x89, 0x50, 0x4E, 0x47]),
    ('JPEG', <int>[0xFF, 0xD8, 0xFF]),
    ('GIF', <int>[0x47, 0x49, 0x46, 0x38]),
    ('PDF', <int>[0x25, 0x50, 0x44, 0x46]),
    ('ZIP', <int>[0x50, 0x4B, 0x03, 0x04]),
    ('GZIP', <int>[0x1F, 0x8B]),
  ];

  @override
  String get id => 'core.file_type';

  @override
  String get name => 'Detect File Type';

  @override
  OperationCategory get category => OperationCategory.analysis;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io => _textToText;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final bytes = utf8.encode(input.asText());
    for (final signature in _signatures) {
      if (_matches(bytes, signature.$2)) {
        return TextBuffer(signature.$1);
      }
    }
    return const TextBuffer('Tidak dikenal');
  }

  bool _matches(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) {
      return false;
    }
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) {
        return false;
      }
    }
    return true;
  }
}

final class StringsOperation implements Operation {
  const StringsOperation();

  @override
  String get id => 'core.strings';

  @override
  String get name => 'Extract Strings';

  @override
  OperationCategory get category => OperationCategory.analysis;

  @override
  List<OperationParam> get params => const <OperationParam>[
    OperationParam(
      key: 'min_length',
      label: 'Panjang minimum',
      type: OperationParamType.integer,
      defaultValue: 4,
      min: 1,
      max: 256,
    ),
  ];

  @override
  OperationIO get io => _textToText;

  static final RegExp _printable = RegExp(r'[\x20-\x7E]+');

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final minLength = args['min_length'] is int
        ? args['min_length']! as int
        : 4;
    final matches = _printable
        .allMatches(input.asText())
        .map((match) => match.group(0)!)
        .where((value) => value.length >= minLength);
    return TextBuffer(matches.join('\n'));
  }
}
