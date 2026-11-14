import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/step_card.dart';
import 'package:flutter/material.dart';
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
  testWidgets('menampilkan nama, kategori, dan badge tier', (tester) async {
    await tester.pumpWidget(
      _host(
        const StepCard(
          name: 'Base64 Decode',
          category: 'Encode/Decode',
          tier: 'dsl',
        ),
      ),
    );

    expect(find.text('Base64 Decode'), findsOneWidget);
    expect(find.text('Encode/Decode'), findsOneWidget);
    expect(find.text('dsl'), findsOneWidget);
  });

  testWidgets('toggle enabled memanggil callback', (tester) async {
    bool? value;
    await tester.pumpWidget(
      _host(
        StepCard(
          name: 'XOR',
          category: 'Crypto',
          onEnabledChanged: (next) => value = next,
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    expect(value, isFalse);
  });

  testWidgets('state error menampilkan pesan dan border danger', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const StepCard(
          name: 'Gzip',
          category: 'Format',
          state: StepCardState.error,
          errorMessage: 'Input bukan gzip.',
        ),
      ),
    );

    expect(find.text('Input bukan gzip.'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('state unsupported menonaktifkan tap dan toggle', (tester) async {
    var taps = 0;
    bool? toggle;
    await tester.pumpWidget(
      _host(
        StepCard(
          name: 'Lua Op',
          category: 'Utility',
          state: StepCardState.unsupported,
          onTap: () => taps++,
          onEnabledChanged: (next) => toggle = next,
        ),
      ),
    );

    expect(find.text('unsupported'), findsOneWidget);
    await tester.tap(find.text('Lua Op'));
    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.onChanged, isNull);
    expect(taps, 0);
    expect(toggle, isNull);
  });

  testWidgets('state disabled meredupkan konten', (tester) async {
    await tester.pumpWidget(
      _host(
        const StepCard(
          name: 'Dim',
          category: 'Utility',
          state: StepCardState.disabled,
          enabled: false,
        ),
      ),
    );

    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 0.5);
  });

  testWidgets('onDelete menampilkan tombol hapus', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      _host(
        StepCard(
          name: 'XOR',
          category: 'Crypto',
          onDelete: () => deleted = true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Hapus step'));
    expect(deleted, isTrue);
  });

  testWidgets('tanpa aksi atur tidak menampilkan chevron', (tester) async {
    await tester.pumpWidget(
      _host(const StepCard(name: 'Base64 Encode', category: 'Encode/Decode')),
    );

    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byTooltip('Atur step'), findsNothing);
  });

  testWidgets('aksi atur menampilkan chevron', (tester) async {
    await tester.pumpWidget(
      _host(StepCard(name: 'Slice', category: 'Utility', onTap: () {})),
    );

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byTooltip('Atur step'), findsOneWidget);
  });
}
