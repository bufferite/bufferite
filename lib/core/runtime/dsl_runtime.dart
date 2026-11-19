import 'dart:convert';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import '../operations/safe_regex.dart';
import '../plugin/plugin_permission.dart';
import 'sandbox.dart';

/// Versi skema DSL yang didukung (keputusan D08).
const int dslSchemaVersion = 1;

/// Batas jumlah step per program DSL.
const int dslMaxSteps = 200;

/// Program DSL hasil parse `transform.json` (tier `dsl`).
final class DslProgram {
  DslProgram(List<DslStep> steps) : steps = List<DslStep>.unmodifiable(steps);

  final List<DslStep> steps;
}

sealed class DslStep {
  const DslStep();
}

/// Ganti substring literal (pemetaan nilai).
final class DslMapStep extends DslStep {
  DslMapStep({required Map<String, String> mapping, this.all = true})
    : mapping = Map<String, String>.unmodifiable(mapping);

  final Map<String, String> mapping;
  final bool all;
}

/// Regex replace memakai [SafeRegex] (anti-ReDoS).
final class DslRegexStep extends DslStep {
  DslRegexStep({
    required this.pattern,
    required this.replacement,
    this.ignoreCase = false,
    this.all = true,
  });

  final String pattern;
  final String replacement;
  final bool ignoreCase;
  final bool all;
}

/// Konversi angka + satuan (panjang, massa, data, waktu, suhu).
final class DslConvertStep extends DslStep {
  DslConvertStep({required this.from, required this.to});

  final String from;
  final String to;
}

/// Ganti nama key objek JSON (rekursif pada objek di dalam list).
final class DslRenameStep extends DslStep {
  DslRenameStep({required Map<String, String> mapping})
    : mapping = Map<String, String>.unmodifiable(mapping);

  final Map<String, String> mapping;
}

/// Runtime DSL: menerjemahkan [DslProgram] menjadi transformasi teks.
///
/// Hanya butuh izin `cpu`; tidak ada akses net/fs dan tidak ada evaluasi kode.
/// Timeout ditegakkan host isolate (F03-T04); pembatalan diperiksa antar step.
final class DslRuntime implements SandboxRuntime {
  DslRuntime(this.program);

  /// Parse sumber JSON `transform.json`. Melempar [AppError] `plugin.dsl_invalid`.
  factory DslRuntime.parse(String source) {
    return DslRuntime(_parseProgram(source));
  }

  final DslProgram program;

  @override
  Future<Buffer> execute(
    Buffer input,
    Map<String, Object?> args,
    SandboxContext context,
  ) async {
    context.ensureActive();
    context.requirePermission(PluginPermission.cpu);
    if (input.kind == BufferKind.file) {
      throw AppError(
        category: ErrorCategory.runtime,
        code: 'runtime.file_not_materialized',
        message: 'Buffer file harus dimaterialisasi sebelum runtime DSL.',
        pluginId: context.pluginId,
        stepId: context.stepId,
      );
    }

    var text = input.asText();

    for (final step in program.steps) {
      context.ensureActive();
      text = switch (step) {
        DslMapStep() => _applyMap(text, step),
        DslRegexStep() => _applyRegex(text, step),
        DslConvertStep() => _applyConvert(text, step),
        DslRenameStep() => _applyRename(text, step),
      };
    }

    return TextBuffer(text);
  }

  String _applyMap(String text, DslMapStep step) {
    var result = text;
    for (final entry in step.mapping.entries) {
      result = step.all
          ? result.replaceAll(entry.key, entry.value)
          : result.replaceFirst(entry.key, entry.value);
    }
    return result;
  }

  String _applyRegex(String text, DslRegexStep step) {
    return step.all
        ? SafeRegex.replaceAll(
            text,
            pattern: step.pattern,
            replacement: step.replacement,
            ignoreCase: step.ignoreCase,
          )
        : SafeRegex.replaceFirst(
            text,
            pattern: step.pattern,
            replacement: step.replacement,
            ignoreCase: step.ignoreCase,
          );
  }

  String _applyConvert(String text, DslConvertStep step) {
    final fromUnit = _unit(step.from);
    final toUnit = _unit(step.to);
    if (fromUnit.kind != toUnit.kind) {
      throw _invalidInput(
        'Satuan "${step.from}" dan "${step.to}" tidak sejenis.',
      );
    }

    final match = _numberPattern.firstMatch(text.trim());
    if (match == null) {
      throw _invalidInput('Input bukan angka dengan satuan yang dikenal.');
    }

    final raw = double.tryParse(match.group(1)!);
    if (raw == null || raw.isNaN || raw.isInfinite) {
      throw _invalidInput('Angka tidak valid.');
    }

    final unitText = match.group(2);
    _Unit source = fromUnit;
    if (unitText != null && unitText.isNotEmpty) {
      final parsed = _findUnit(unitText);
      if (parsed == null) {
        throw _invalidInput('Satuan "$unitText" tidak dikenal.');
      }
      if (parsed.kind != fromUnit.kind) {
        throw _invalidInput(
          'Satuan "$unitText" tidak sejenis dengan "${step.from}".',
        );
      }
      source = parsed;
    }

    final converted = _convertValue(raw, source, toUnit);
    return _formatNumber(converted);
  }

  String _applyRename(String text, DslRenameStep step) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw _invalidInput('Input bukan JSON yang valid.');
    }
    if (decoded is! Map<String, Object?>) {
      throw _invalidInput('JSON harus berupa objek untuk di-rename.');
    }
    return jsonEncode(_renameNode(decoded, step.mapping));
  }

  Object? _renameNode(Object? node, Map<String, String> mapping) {
    if (node is Map<String, Object?>) {
      final seen = <String>{};
      final renamed = <String, Object?>{};
      for (final entry in node.entries) {
        final key = mapping[entry.key] ?? entry.key;
        if (!seen.add(key)) {
          throw _invalidInput('Rename menghasilkan key ganda: "$key".');
        }
        renamed[key] = _renameNode(entry.value, mapping);
      }
      return renamed;
    }
    if (node is List<Object?>) {
      return <Object?>[for (final item in node) _renameNode(item, mapping)];
    }
    return node;
  }

  double _convertValue(double value, _Unit source, _Unit target) {
    final base = source.kind == _UnitKind.temperature
        ? _toBase(value, source)
        : value * source.factor;
    if (target.kind != _UnitKind.temperature) {
      return base / target.factor;
    }
    return switch (target.name) {
      'c' => base,
      'f' => base * 9 / 5 + 32,
      _ => base + 273.15,
    };
  }

  double _toBase(double value, _Unit unit) {
    return switch (unit.name) {
      'c' => value,
      'f' => (value - 32) * 5 / 9,
      _ => value - 273.15,
    };
  }
}

// --- Parsing program ---

DslProgram _parseProgram(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw _invalid('JSON tidak valid: ${error.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw _invalid('Program DSL harus berupa objek JSON.');
  }

  _rejectUnknownKeys(decoded, const <String>{
    'version',
    'steps',
    'description',
  });

  final version = decoded['version'];
  if (version != dslSchemaVersion) {
    throw _invalid('Field "version" harus $dslSchemaVersion.');
  }

  final rawSteps = decoded['steps'];
  if (rawSteps is! List<Object?>) {
    throw _invalid('Field "steps" harus berupa array.');
  }
  if (rawSteps.isEmpty) {
    throw _invalid('Field "steps" tidak boleh kosong.');
  }
  if (rawSteps.length > dslMaxSteps) {
    throw _invalid('Jumlah step melebihi batas $dslMaxSteps.');
  }

  final steps = <DslStep>[];
  for (var index = 0; index < rawSteps.length; index++) {
    final raw = rawSteps[index];
    if (raw is! Map<String, Object?>) {
      throw _invalid('Step #$index harus berupa objek.');
    }
    steps.add(_parseStep(raw, index));
  }
  return DslProgram(steps);
}

DslStep _parseStep(Map<String, Object?> json, int index) {
  final op = json['op'];
  if (op is! String) {
    throw _invalid('Step #$index: field "op" wajib diisi.');
  }

  switch (op) {
    case 'map':
      _rejectUnknownKeys(json, const <String>{'op', 'mapping', 'all'});
      return DslMapStep(
        mapping: _parseMapping(json['mapping'], 'Step #$index'),
        all: _parseBool(json['all'], defaultValue: true, label: 'Step #$index'),
      );
    case 'regex_replace':
      _rejectUnknownKeys(json, const <String>{
        'op',
        'pattern',
        'replacement',
        'ignore_case',
        'all',
      });
      final pattern = json['pattern'];
      if (pattern is! String || pattern.isEmpty) {
        throw _invalid('Step #$index: field "pattern" wajib diisi.');
      }
      final replacement = json['replacement'];
      if (replacement != null && replacement is! String) {
        throw _invalid('Step #$index: field "replacement" harus string.');
      }
      return DslRegexStep(
        pattern: pattern,
        replacement: replacement is String ? replacement : '',
        ignoreCase: _parseBool(
          json['ignore_case'],
          defaultValue: false,
          label: 'Step #$index',
        ),
        all: _parseBool(json['all'], defaultValue: true, label: 'Step #$index'),
      );
    case 'convert_unit':
      _rejectUnknownKeys(json, const <String>{'op', 'from', 'to'});
      final from = json['from'];
      final to = json['to'];
      if (from is! String || from.isEmpty || to is! String || to.isEmpty) {
        throw _invalid(
          'Step #$index: field "from" dan "to" wajib berisi satuan.',
        );
      }
      _unit(from);
      _unit(to);
      return DslConvertStep(from: from, to: to);
    case 'rename':
      _rejectUnknownKeys(json, const <String>{'op', 'mapping'});
      return DslRenameStep(
        mapping: _parseMapping(json['mapping'], 'Step #$index'),
      );
    default:
      throw _invalid('Step #$index: op "$op" tidak dikenal.');
  }
}

Map<String, String> _parseMapping(Object? raw, String label) {
  if (raw is! Map<Object?, Object?>) {
    throw _invalid('$label: field "mapping" harus berupa objek.');
  }
  final mapping = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || value is! String) {
      throw _invalid('$label: kunci dan nilai mapping harus string.');
    }
    if (key.isEmpty) {
      throw _invalid('$label: kunci mapping tidak boleh kosong.');
    }
    mapping[key] = value;
  }
  if (mapping.isEmpty) {
    throw _invalid('$label: field "mapping" tidak boleh kosong.');
  }
  return mapping;
}

bool _parseBool(
  Object? raw, {
  required bool defaultValue,
  required String label,
}) {
  if (raw == null) {
    return defaultValue;
  }
  if (raw is! bool) {
    throw _invalid('$label: nilai boolean tidak valid.');
  }
  return raw;
}

void _rejectUnknownKeys(Map<String, Object?> json, Set<String> allowed) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      throw _invalid('Field "$key" tidak dikenal.');
    }
  }
}

// --- Satuan ---

enum _UnitKind { length, mass, data, time, temperature }

final class _Unit {
  const _Unit(this.name, this.kind, this.factor);

  final String name;
  final _UnitKind kind;

  /// Faktor ke satuan dasar (meter, kilogram, byte, detik).
  final double factor;
}

const Map<String, _Unit> _units = <String, _Unit>{
  'm': _Unit('m', _UnitKind.length, 1),
  'km': _Unit('km', _UnitKind.length, 1000),
  'cm': _Unit('cm', _UnitKind.length, 0.01),
  'mm': _Unit('mm', _UnitKind.length, 0.001),
  'mi': _Unit('mi', _UnitKind.length, 1609.344),
  'yd': _Unit('yd', _UnitKind.length, 0.9144),
  'ft': _Unit('ft', _UnitKind.length, 0.3048),
  'in': _Unit('in', _UnitKind.length, 0.0254),
  'kg': _Unit('kg', _UnitKind.mass, 1),
  'g': _Unit('g', _UnitKind.mass, 0.001),
  'mg': _Unit('mg', _UnitKind.mass, 0.000001),
  't': _Unit('t', _UnitKind.mass, 1000),
  'lb': _Unit('lb', _UnitKind.mass, 0.45359237),
  'oz': _Unit('oz', _UnitKind.mass, 0.028349523125),
  'b': _Unit('b', _UnitKind.data, 1),
  'kb': _Unit('kb', _UnitKind.data, 1000),
  'mb': _Unit('mb', _UnitKind.data, 1000000),
  'gb': _Unit('gb', _UnitKind.data, 1000000000),
  'tb': _Unit('tb', _UnitKind.data, 1000000000000),
  'kib': _Unit('kib', _UnitKind.data, 1024),
  'mib': _Unit('mib', _UnitKind.data, 1048576),
  'gib': _Unit('gib', _UnitKind.data, 1073741824),
  's': _Unit('s', _UnitKind.time, 1),
  'ms': _Unit('ms', _UnitKind.time, 0.001),
  'min': _Unit('min', _UnitKind.time, 60),
  'h': _Unit('h', _UnitKind.time, 3600),
  'day': _Unit('day', _UnitKind.time, 86400),
  'c': _Unit('c', _UnitKind.temperature, 1),
  'f': _Unit('f', _UnitKind.temperature, 1),
  'k': _Unit('k', _UnitKind.temperature, 1),
};

final RegExp _numberPattern = RegExp(
  r'^([+-]?(?:\d+(?:\.\d*)?|\.\d+))\s*([a-zA-Z]*)$',
);

_Unit _unit(String name) {
  return _findUnit(name) ?? (throw _invalid('Satuan "$name" tidak dikenal.'));
}

_Unit? _findUnit(String name) {
  return _units[name.toLowerCase()];
}

String _formatNumber(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toStringAsFixed(0);
  }
  return value
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

AppError _invalid(String message) {
  return AppError(
    category: ErrorCategory.plugin,
    code: 'plugin.dsl_invalid',
    message: message,
  );
}

AppError _invalidInput(String message) {
  return AppError(
    category: ErrorCategory.validation,
    code: 'operation.invalid_input',
    message: message,
  );
}
