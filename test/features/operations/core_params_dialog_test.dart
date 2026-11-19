import 'package:bufferite/core/i18n/app_localizations.dart';
import 'package:bufferite/core/operations/core_operations.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/operations/step_config_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final localizations = AppLocalizations.current;
  final withParams = coreOperations
      .where((operation) => operation.params.isNotEmpty)
      .toList();

  test('ada operasi inti berparameter untuk diuji', () {
    expect(withParams, isNotEmpty);
  });

  for (final operation in withParams) {
    testWidgets('dialog ${operation.id} menampilkan semua parameter', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StepConfigDialog(
              operationId: operation.id,
              title: localizations.trOr(
                'operations.${operation.id}.name',
                operation.name,
              ),
              params: operation.params,
              initialArgs: const <String, Object?>{},
            ),
          ),
        ),
      );

      expect(
        find.text(
          localizations.trOr('operations.${operation.id}.name', operation.name),
        ),
        findsOneWidget,
      );
      for (final param in operation.params) {
        expect(
          find.text(
            localizations.trOr(
              'operations.${operation.id}.params.${param.key}.label',
              param.label,
            ),
          ),
          findsWidgets,
          reason: 'Parameter ${param.key} tidak tampil untuk ${operation.id}',
        );
      }
    });
  }

  testWidgets('parameter inti tampil dalam bahasa Inggris', (tester) async {
    final en = AppLocalizations.forLocale(const Locale('en'));
    final operation = coreOperations.firstWhere(
      (operation) => operation.id == 'core.aes_encrypt',
    );

    await tester.pumpWidget(
      AppLocalizationsScope(
        localizations: en,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StepConfigDialog(
              operationId: operation.id,
              title: en.tr('operations.${operation.id}.name'),
              params: operation.params,
              initialArgs: const <String, Object?>{},
            ),
          ),
        ),
      ),
    );

    expect(find.text('AES Encrypt'), findsOneWidget);
    expect(find.text('Key (hex)'), findsOneWidget);
    expect(
      find.text('32/48/64 hex characters (AES-128/192/256).'),
      findsOneWidget,
    );
    expect(find.text('Output format'), findsOneWidget);
  });

  testWidgets('operasi tanpa parameter memberi keterangan', (tester) async {
    final withoutParams = coreOperations.firstWhere(
      (operation) => operation.params.isEmpty,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StepConfigDialog(
            operationId: withoutParams.id,
            title: localizations.trOr(
              'operations.${withoutParams.id}.name',
              withoutParams.name,
            ),
            params: const [],
            initialArgs: const <String, Object?>{},
          ),
        ),
      ),
    );

    expect(find.text('Operasi ini tidak punya parameter.'), findsOneWidget);
  });
}
