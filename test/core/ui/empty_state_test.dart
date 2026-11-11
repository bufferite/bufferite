import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('menampilkan ikon, judul, dan deskripsi', (tester) async {
    await tester.pumpWidget(
      _host(
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Belum ada recipe',
          description: 'Buat recipe pertamamu.',
        ),
      ),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('Belum ada recipe'), findsOneWidget);
    expect(find.text('Buat recipe pertamamu.'), findsOneWidget);
  });

  testWidgets('aksi utama memanggil callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        EmptyState(
          icon: Icons.add,
          title: 'Kosong',
          actionLabel: 'Buat recipe baru',
          onAction: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Buat recipe baru'));
    expect(tapped, isTrue);
  });

  testWidgets('tanpa aksi tidak menampilkan tombol', (tester) async {
    await tester.pumpWidget(
      _host(const EmptyState(icon: Icons.inbox_outlined, title: 'Kosong')),
    );

    expect(find.byType(FilledButton), findsNothing);
  });
}
