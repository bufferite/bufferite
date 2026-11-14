import 'package:bufferite/core/operations/core_operations.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/operations/step_config_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final withParams = coreOperations
      .where((operation) => operation.params.isNotEmpty)
      .toList();

  test('ada operasi inti berparameter untuk diuji', () {
    expect(withParams, isNotEmpty);
  });

  for (final operation in withParams) {
    testWidgets('sheet ${operation.id} menampilkan semua parameter', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StepConfigSheet(
              title: operation.name,
              params: operation.params,
              initialArgs: const <String, Object?>{},
            ),
          ),
        ),
      );

      expect(find.text(operation.name), findsOneWidget);
      for (final param in operation.params) {
        expect(
          find.text(param.label),
          findsWidgets,
          reason: 'Parameter ${param.key} tidak tampil untuk ${operation.id}',
        );
      }
    });
  }

  testWidgets('operasi tanpa parameter memberi keterangan', (tester) async {
    final withoutParams = coreOperations.firstWhere(
      (operation) => operation.params.isEmpty,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StepConfigSheet(
            title: withoutParams.name,
            params: const [],
            initialArgs: const <String, Object?>{},
          ),
        ),
      ),
    );

    expect(find.text('Operasi ini tidak punya parameter.'), findsOneWidget);
  });
}
