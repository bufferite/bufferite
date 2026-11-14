import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(VoidCallback onPressed) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: onPressed,
            child: const Text('Trigger'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('menampilkan pesan dengan ikon sesuai tone', (tester) async {
    await tester.pumpWidget(
      _host(() {
        final context = tester.element(find.text('Trigger'));
        showAppToast(context, message: 'Tersimpan', tone: AppToastTone.success);
      }),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();

    expect(find.text('Tersimpan'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('menampilkan aksi undo dan memanggil callback', (tester) async {
    var undone = false;
    await tester.pumpWidget(
      _host(() {
        final context = tester.element(find.text('Trigger'));
        showAppToast(
          context,
          message: 'Recipe dihapus',
          tone: AppToastTone.warning,
          undoLabel: 'Undo',
          onUndo: () => undone = true,
        );
      }),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();
    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    expect(action.label, 'Undo');

    action.onPressed();
    await tester.pump();
    expect(undone, isTrue);
  });

  testWidgets('tanpa undo tidak menampilkan aksi', (tester) async {
    await tester.pumpWidget(
      _host(() {
        final context = tester.element(find.text('Trigger'));
        showAppToast(context, message: 'Info', tone: AppToastTone.info);
      }),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();

    expect(find.byType(SnackBarAction), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('toast baru menggantikan toast lama tanpa menumpuk', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(() {
        final context = tester.element(find.text('Trigger'));
        showAppToast(context, message: 'Pertama');
        showAppToast(context, message: 'Kedua');
      }),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Kedua'), findsOneWidget);
    expect(find.text('Pertama'), findsNothing);
  });

  testWidgets('toast hilang otomatis walau accessibleNavigation aktif', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: _host(() {
          final context = tester.element(find.text('Trigger'));
          showAppToast(context, message: 'Sementara', undoLabel: 'Undo');
        }),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();
    expect(find.text('Sementara'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Sementara'), findsNothing);
  });
}
