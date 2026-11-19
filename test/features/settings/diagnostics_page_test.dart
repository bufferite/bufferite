import 'dart:io';

import 'package:bufferite/core/diagnostics/diagnostics_providers.dart';
import 'package:bufferite/core/diagnostics/execution_log.dart';
import 'package:bufferite/core/diagnostics/execution_log_store.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/settings/diagnostics_page.dart';
import 'package:bufferite/features/settings/settings_provider.dart';
import 'package:bufferite/features/settings/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/support/async_pump.dart';

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this.logging);

  final bool logging;

  @override
  Future<AppSettings> build() async {
    return AppSettings.defaults.copyWith(optInLogging: logging);
  }
}

ExecutionLogEntry _entry({
  String name = 'Alpha',
  ExecutionOutcome outcome = ExecutionOutcome.success,
  List<String> errorCodes = const <String>[],
}) {
  return ExecutionLogEntry(
    timestamp: DateTime(2026, 11, 19, 10, 0),
    recipeName: name,
    operationIds: const <String>['core.reverse'],
    durationMs: 7,
    outcome: outcome,
    errorCodes: errorCodes,
  );
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bufferite_diagnostics_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      await temp.delete(recursive: true);
    }
  });

  ExecutionLogStore store() {
    return ExecutionLogStore(directory: () async => temp);
  }

  ExecutionLogService service({bool enabled = true}) {
    return ExecutionLogService(store: store(), isEnabled: () async => enabled);
  }

  Future<void> pumpPage(
    WidgetTester tester,
    ExecutionLogService logService, {
    bool logging = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          executionLogServiceProvider.overrideWithValue(logService),
          settingsProvider.overrideWith(() => _FakeSettingsController(logging)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DiagnosticsPage(),
        ),
      ),
    );
    await tester.pump();
    await pumpUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan empty state saat belum ada log', (tester) async {
    await pumpPage(tester, service());

    expect(find.text('Belum ada log eksekusi'), findsOneWidget);
    expect(
      find.text(
        'Jalankan preview recipe setelah mengaktifkan log untuk melihat '
        'riwayat di sini.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('menampilkan entri log dengan operasi dan kode error', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final log = store();
      await log.append(_entry());
      await log.append(
        _entry(
          name: 'Beta',
          outcome: ExecutionOutcome.failed,
          errorCodes: const <String>['plugin.timeout'],
        ),
      );
    });

    await pumpPage(tester, service());

    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Gagal'), findsOneWidget);
    expect(find.text('Berhasil'), findsOneWidget);
    expect(find.text('core.reverse'), findsNWidgets(2));
    expect(find.text('Kode error: plugin.timeout'), findsOneWidget);
  });

  testWidgets('menampilkan peringatan saat log nonaktif', (tester) async {
    await pumpPage(tester, service(), logging: false);

    expect(
      find.text(
        'Log eksekusi sedang nonaktif. Aktifkan lewat Settings > '
        'Privasi & Log.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hapus log lewat dialog konfirmasi', (tester) async {
    await tester.runAsync(() async {
      await store().append(_entry());
    });
    final logService = service();
    await pumpPage(tester, logService);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Hapus log diagnostik?'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pump();
    await pumpUntil(
      tester,
      () => find.text('Belum ada log eksekusi').evaluate().isNotEmpty,
    );

    expect(find.text('Alpha'), findsNothing);
    await tester.runAsync(() async {
      expect(await logService.recent(), isEmpty);
    });
  });
}
