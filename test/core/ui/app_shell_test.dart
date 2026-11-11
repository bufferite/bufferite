import 'package:bufferite/core/ui/app_shell.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menampilkan 3 tab dan berpindah antar tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const AppShell()),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Belum ada recipe'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Katalog operasi'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada recipe'), findsOneWidget);
  });

  testWidgets('state tab terjaga lewat IndexedStack', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const AppShell()),
    );

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, 1);
    expect(stack.children, hasLength(3));
  });
}
