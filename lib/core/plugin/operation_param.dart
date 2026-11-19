import '../error/app_error.dart';
import '../error/result.dart';

enum OperationParamType {
  string,
  integer,
  boolean,
  select;

  static OperationParamType parse(Object? value) {
    if (value is String) {
      for (final type in values) {
        if (type.name == value) {
          return type;
        }
      }
    }
    throw AppError(
      category: ErrorCategory.validation,
      code: 'operation.param_type_invalid',
      message: 'Tipe parameter tidak dikenal: $value',
    );
  }
}

final class OperationParamOption {
  const OperationParamOption({required this.value, required this.label});

  final String value;
  final String label;

  factory OperationParamOption.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw _paramError('Opsi parameter harus berupa objek.');
    }
    final value = json['value'];
    final label = json['label'];
    if (value is! String || label is! String) {
      throw _paramError('Opsi parameter membutuhkan value dan label string.');
    }
    return OperationParamOption(value: value, label: label);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'value': value, 'label': label};
  }
}

final class OperationParam {
  const OperationParam({
    required this.key,
    required this.label,
    required this.type,
    this.defaultValue,
    this.isRequired = false,
    this.options = const <OperationParamOption>[],
    this.min,
    this.max,
    this.multiline = false,
    this.secret = false,
    this.helpText,
  });

  final String key;
  final String label;
  final OperationParamType type;
  final Object? defaultValue;
  final bool isRequired;
  final List<OperationParamOption> options;
  final int? min;
  final int? max;
  final bool multiline;
  final bool secret;
  final String? helpText;

  factory OperationParam.fromJson(Map<String, Object?> json) {
    final key = json['key'];
    final label = json['label'];
    if (key is! String || label is! String) {
      throw _paramError('Parameter membutuhkan key dan label string.');
    }

    final optionsJson = json['options'];
    final options = <OperationParamOption>[];
    if (optionsJson != null) {
      if (optionsJson is! List<Object?>) {
        throw _paramError('Field options harus berupa array.');
      }
      for (final option in optionsJson) {
        options.add(OperationParamOption.fromJson(option));
      }
    }

    final min = json['min'];
    final max = json['max'];
    if ((min != null && min is! int) || (max != null && max is! int)) {
      throw _paramError('Field min dan max harus berupa integer.');
    }

    final required = json['required'];
    final multiline = json['multiline'];
    final secret = json['secret'];
    if ((required != null && required is! bool) ||
        (multiline != null && multiline is! bool) ||
        (secret != null && secret is! bool)) {
      throw _paramError(
        'Field required, multiline, dan secret harus berupa boolean.',
      );
    }

    final helpText = json['helpText'];
    if (helpText != null && helpText is! String) {
      throw _paramError('Field helpText harus berupa string.');
    }

    final param = OperationParam(
      key: key,
      label: label,
      type: OperationParamType.parse(json['type']),
      defaultValue: json['default'],
      isRequired: required as bool? ?? false,
      options: List<OperationParamOption>.unmodifiable(options),
      min: min as int?,
      max: max as int?,
      multiline: multiline as bool? ?? false,
      secret: secret as bool? ?? false,
      helpText: helpText as String?,
    );

    final definitionError = param.validateDefinition();
    if (definitionError != null) {
      throw definitionError;
    }
    return param;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'key': key,
      'label': label,
      'type': type.name,
      if (defaultValue != null) 'default': defaultValue,
      'required': isRequired,
      if (options.isNotEmpty)
        'options': options.map((option) => option.toJson()).toList(),
      if (min != null) 'min': min,
      if (max != null) 'max': max,
      if (multiline) 'multiline': true,
      if (secret) 'secret': true,
      if (helpText != null) 'helpText': helpText,
    };
  }

  /// Memvalidasi definisi parameter (dipakai saat parsing manifest).
  AppError? validateDefinition() {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key)) {
      return _paramError(
        'Key parameter harus snake_case dan dimulai huruf: $key',
      );
    }
    if (label.trim().isEmpty) {
      return _paramError('Label parameter tidak boleh kosong.');
    }
    if (min != null && max != null && min! > max!) {
      return _paramError('Nilai min tidak boleh lebih besar dari max.');
    }
    if (type != OperationParamType.integer && (min != null || max != null)) {
      return _paramError('Field min/max hanya untuk parameter integer.');
    }
    if (type != OperationParamType.select && options.isNotEmpty) {
      return _paramError('Field options hanya untuk parameter select.');
    }

    if (type == OperationParamType.select) {
      if (options.isEmpty) {
        return _paramError('Parameter select wajib memiliki opsi.');
      }
      final values = <String>{};
      for (final option in options) {
        if (!values.add(option.value)) {
          return _paramError('Opsi select duplikat: ${option.value}');
        }
      }
    }

    if (defaultValue != null) {
      final result = validate(defaultValue);
      if (!result.isSuccess) {
        return result.errorOrNull;
      }
    }

    return null;
  }

  Result<Object?> validate(Object? value) {
    if (value == null) {
      if (isRequired) {
        return Err<Object?>(
          _paramError(
            'Parameter "$key" wajib diisi.',
            code: 'operation.param_required',
            details: <String, Object?>{'param': key, 'label': label},
          ),
        );
      }
      return const Ok<Object?>(null);
    }

    switch (type) {
      case OperationParamType.string:
        if (value is! String) {
          return Err<Object?>(_typeError('string', value));
        }
        return Ok<Object?>(value);

      case OperationParamType.integer:
        if (value is! int) {
          return Err<Object?>(_typeError('integer', value));
        }
        if (min != null && value < min!) {
          return Err<Object?>(
            _paramError(
              'Parameter "$key" minimal $min.',
              code: 'operation.param_out_of_range',
              details: <String, Object?>{
                'param': key,
                'label': label,
                'min': min,
              },
            ),
          );
        }
        if (max != null && value > max!) {
          return Err<Object?>(
            _paramError(
              'Parameter "$key" maksimal $max.',
              code: 'operation.param_out_of_range',
              details: <String, Object?>{
                'param': key,
                'label': label,
                'max': max,
              },
            ),
          );
        }
        return Ok<Object?>(value);

      case OperationParamType.boolean:
        if (value is! bool) {
          return Err<Object?>(_typeError('boolean', value));
        }
        return Ok<Object?>(value);

      case OperationParamType.select:
        if (value is! String) {
          return Err<Object?>(_typeError('string (select)', value));
        }
        if (!options.any((option) => option.value == value)) {
          return Err<Object?>(
            _paramError(
              'Nilai "$value" bukan opsi valid untuk "$key".',
              code: 'operation.param_out_of_range',
              details: <String, Object?>{
                'param': key,
                'label': label,
                'value': value,
              },
            ),
          );
        }
        return Ok<Object?>(value);
    }
  }

  AppError _typeError(String expected, Object? actual) {
    return _paramError(
      'Parameter "$key" harus bertipe $expected.',
      code: 'operation.param_type_mismatch',
      details: <String, Object?>{
        'param': key,
        'label': label,
        'expected': expected,
        'actual': actual.runtimeType.toString(),
      },
    );
  }
}

/// Menerapkan default, menolak argumen tak dikenal, lalu memvalidasi semua
/// parameter. Hasilnya siap diberikan ke [Operation.execute].
Result<Map<String, Object?>> resolveOperationArgs(
  List<OperationParam> params,
  Map<String, Object?> args,
) {
  final keys = <String>{};
  for (final param in params) {
    if (!keys.add(param.key)) {
      return Err<Map<String, Object?>>(
        _paramError(
          'Definisi parameter duplikat: ${param.key}',
          code: 'operation.param_duplicate',
          details: <String, Object?>{'param': param.key},
        ),
      );
    }
    final definitionError = param.validateDefinition();
    if (definitionError != null) {
      return Err<Map<String, Object?>>(definitionError);
    }
  }

  for (final key in args.keys) {
    if (!keys.contains(key)) {
      return Err<Map<String, Object?>>(
        _paramError(
          'Argumen tidak dikenal: $key',
          code: 'operation.param_unknown',
          details: <String, Object?>{'param': key},
        ),
      );
    }
  }

  final resolved = <String, Object?>{};
  for (final param in params) {
    final raw = args.containsKey(param.key)
        ? args[param.key]
        : param.defaultValue;
    final result = param.validate(raw);
    if (!result.isSuccess) {
      return Err<Map<String, Object?>>(result.errorOrNull!);
    }
    final value = result.valueOrNull;
    if (value != null) {
      resolved[param.key] = value;
    }
  }

  return Ok<Map<String, Object?>>(Map<String, Object?>.unmodifiable(resolved));
}

AppError _paramError(
  String message, {
  String code = 'operation.param_invalid',
  Map<String, Object?> details = const <String, Object?>{},
}) {
  return AppError(
    category: ErrorCategory.validation,
    code: code,
    message: message,
    details: details,
  );
}
