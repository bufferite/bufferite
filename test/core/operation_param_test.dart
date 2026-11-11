import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/operation_param.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const params = <OperationParam>[
    OperationParam(
      key: 'mode',
      label: 'Mode',
      type: OperationParamType.select,
      defaultValue: 'lower',
      options: <OperationParamOption>[
        OperationParamOption(value: 'lower', label: 'Lower'),
        OperationParamOption(value: 'upper', label: 'Upper'),
      ],
    ),
    OperationParam(
      key: 'count',
      label: 'Count',
      type: OperationParamType.integer,
      min: 1,
      max: 5,
    ),
    OperationParam(
      key: 'enabled',
      label: 'Enabled',
      type: OperationParamType.boolean,
      defaultValue: false,
    ),
    OperationParam(
      key: 'text',
      label: 'Text',
      type: OperationParamType.string,
      isRequired: true,
    ),
  ];

  group('resolveOperationArgs', () {
    test('menerapkan default dan membuang nilai opsional kosong', () {
      final result = resolveOperationArgs(params, <String, Object?>{
        'text': 'halo',
      });

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, <String, Object?>{
        'mode': 'lower',
        'enabled': false,
        'text': 'halo',
      });
    });

    test('menolak argumen tak dikenal', () {
      final result = resolveOperationArgs(params, <String, Object?>{
        'text': 'halo',
        'unknown': 1,
      });

      expect(result.errorOrNull?.code, 'operation.param_unknown');
    });

    test('menolak parameter wajib yang kosong', () {
      final result = resolveOperationArgs(params, const <String, Object?>{});

      expect(result.errorOrNull?.code, 'operation.param_required');
    });

    test('menolak tipe yang salah', () {
      final result = resolveOperationArgs(params, <String, Object?>{
        'text': 1,
        'count': 2.0,
      });

      expect(result.errorOrNull?.code, 'operation.param_type_mismatch');
    });

    test('menolak nilai integer di luar rentang', () {
      for (final count in <int>[0, 6]) {
        final result = resolveOperationArgs(params, <String, Object?>{
          'text': 'halo',
          'count': count,
        });

        expect(result.errorOrNull?.code, 'operation.param_out_of_range');
      }
    });

    test('menolak opsi select yang tidak valid', () {
      final result = resolveOperationArgs(params, <String, Object?>{
        'text': 'halo',
        'mode': 'sideways',
      });

      expect(result.errorOrNull?.code, 'operation.param_out_of_range');
    });

    test('menolak definisi parameter duplikat', () {
      final result = resolveOperationArgs(const <OperationParam>[
        OperationParam(key: 'x', label: 'X', type: OperationParamType.string),
        OperationParam(
          key: 'x',
          label: 'X lagi',
          type: OperationParamType.string,
        ),
      ], const <String, Object?>{});

      expect(result.errorOrNull?.code, 'operation.param_duplicate');
    });

    test('menolak default yang tidak sesuai tipe', () {
      final result = resolveOperationArgs(const <OperationParam>[
        OperationParam(
          key: 'count',
          label: 'Count',
          type: OperationParamType.integer,
          defaultValue: 'satu',
        ),
      ], const <String, Object?>{});

      expect(result.errorOrNull?.code, 'operation.param_type_mismatch');
    });
  });

  group('OperationParam', () {
    test('validateDefinition menolak definisi tidak valid', () {
      const invalid = <OperationParam>[
        OperationParam(
          key: 'BadKey',
          label: 'Bad',
          type: OperationParamType.string,
        ),
        OperationParam(
          key: 'select',
          label: 'Select',
          type: OperationParamType.select,
        ),
        OperationParam(
          key: 'range',
          label: 'Range',
          type: OperationParamType.integer,
          min: 10,
          max: 1,
        ),
        OperationParam(
          key: 'string',
          label: 'String',
          type: OperationParamType.string,
          options: <OperationParamOption>[
            OperationParamOption(value: 'a', label: 'A'),
          ],
        ),
      ];

      for (final param in invalid) {
        expect(param.validateDefinition(), isNotNull, reason: param.key);
      }
    });

    test('fromJson/toJson round-trip', () {
      final param = OperationParam.fromJson(<String, Object?>{
        'key': 'mode',
        'label': 'Mode',
        'type': 'select',
        'default': 'a',
        'required': true,
        'options': <Object?>[
          <String, Object?>{'value': 'a', 'label': 'A'},
          <String, Object?>{'value': 'b', 'label': 'B'},
        ],
        'helpText': 'Pilih mode.',
      });

      expect(param.toJson(), <String, Object?>{
        'key': 'mode',
        'label': 'Mode',
        'type': 'select',
        'default': 'a',
        'required': true,
        'options': <Object?>[
          <String, Object?>{'value': 'a', 'label': 'A'},
          <String, Object?>{'value': 'b', 'label': 'B'},
        ],
        'helpText': 'Pilih mode.',
      });
    });

    test('fromJson menolak tipe dan opsi tidak valid', () {
      expect(
        () => OperationParam.fromJson(<String, Object?>{
          'key': 'x',
          'label': 'X',
          'type': 'unknown',
        }),
        throwsA(isA<AppError>()),
      );
      expect(
        () => OperationParam.fromJson(<String, Object?>{
          'key': 'x',
          'label': 'X',
          'type': 'select',
          'options': <Object?>[
            <String, Object?>{'value': 'a', 'label': 'A'},
            <String, Object?>{'value': 'a', 'label': 'A lagi'},
          ],
        }),
        throwsA(isA<AppError>()),
      );
    });

    test('opsi opsional tanpa default tidak masuk hasil', () {
      const optional = OperationParam(
        key: 'note',
        label: 'Note',
        type: OperationParamType.string,
      );

      final result = resolveOperationArgs(const <OperationParam>[
        optional,
      ], const <String, Object?>{});

      expect(result.valueOrNull, isEmpty);
    });
  });
}
