import 'package:bufferite/core/plugin/operation_param.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/operations/step_config_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _params = <OperationParam>[
  OperationParam(key: 'key', label: 'Key', type: OperationParamType.string),
  OperationParam(
    key: 'shift',
    label: 'Shift',
    type: OperationParamType.integer,
    min: 0,
    max: 10,
  ),
  OperationParam(
    key: 'uppercase',
    label: 'Uppercase',
    type: OperationParamType.boolean,
  ),
  OperationParam(
    key: 'mode',
    label: 'Mode',
    type: OperationParamType.select,
    options: <OperationParamOption>[
      OperationParamOption(value: 'a', label: 'A'),
      OperationParamOption(value: 'b', label: 'B'),
    ],
  ),
];

Future<Map<String, Object?>?> _show(
  WidgetTester tester, {
  Map<String, Object?> initial = const <String, Object?>{},
}) async {
  Map<String, Object?>? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showStepConfigSheet(
                  context,
                  title: 'Konfigurasi',
                  params: _params,
                  initialArgs: initial,
                );
              },
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Buka'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('menampilkan field untuk tiap tipe parameter', (tester) async {
    await _show(tester);

    expect(find.text('Key'), findsOneWidget);
    expect(find.text('Shift'), findsOneWidget);
    expect(find.text('Uppercase'), findsOneWidget);
    expect(find.text('Mode'), findsOneWidget);
  });

  testWidgets('Terapkan mengembalikan args tervalidasi', (tester) async {
    await _show(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Key'), 'secret');
    await tester.enterText(find.widgetWithText(TextField, 'Shift'), '3');
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    expect(find.text('Konfigurasi'), findsNothing);
  });

  testWidgets('nilai integer di luar rentang menampilkan error', (
    tester,
  ) async {
    await _show(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Shift'), '99');
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    expect(find.text('Konfigurasi'), findsOneWidget);
    expect(find.textContaining('maksimal 10'), findsOneWidget);
  });

  testWidgets('memuat nilai awal', (tester) async {
    await _show(
      tester,
      initial: <String, Object?>{'key': 'abc', 'shift': 4, 'uppercase': true},
    );

    expect(find.widgetWithText(TextField, 'abc'), findsOneWidget);
    expect(find.widgetWithText(TextField, '4'), findsOneWidget);
  });
}
