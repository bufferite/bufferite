import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/buffer_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  testWidgets('menampilkan label, tipe, dan konten mono', (tester) async {
    await tester.pumpWidget(
      _host(const BufferPanel(label: 'Input', kind: 'text', content: 'halo')),
    );

    expect(find.text('Input'), findsOneWidget);
    expect(find.text('text'), findsOneWidget);
    expect(find.text('halo'), findsOneWidget);
  });

  testWidgets('empty state menampilkan aksi tempel', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        BufferPanel(
          label: 'Output',
          emptyActionLabel: 'Tempel',
          onEmptyAction: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Belum ada data'), findsOneWidget);
    await tester.tap(find.text('Tempel'));
    expect(tapped, isTrue);
  });

  testWidgets('indikator live dan tombol expand tampil', (tester) async {
    await tester.pumpWidget(
      _host(
        BufferPanel(label: 'Output', content: 'x', live: true, onExpand: () {}),
      ),
    );

    expect(find.text('live'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_full), findsOneWidget);
  });

  testWidgets('banner error ditampilkan di bawah panel', (tester) async {
    await tester.pumpWidget(
      _host(
        const BufferPanel(
          label: 'Output',
          content: 'x',
          errorMessage: 'Gagal decode.',
        ),
      ),
    );

    expect(find.text('Gagal decode.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('copy menaruh konten ke clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      _host(const BufferPanel(label: 'Input', content: 'salin aku')),
    );

    await tester.tap(find.byTooltip('Copy'));
    await tester.pumpAndSettle();
    expect(copied, 'salin aku');
  });
}
