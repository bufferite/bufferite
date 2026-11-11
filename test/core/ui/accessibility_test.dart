import 'package:bufferite/core/ui/app_shell.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/app_button.dart';
import 'package:bufferite/core/ui/components/empty_state.dart';
import 'package:bufferite/core/ui/components/step_card.dart';
import 'package:bufferite/core/ui/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

Widget _scaled(Widget child, {double scale = 1.3}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  test('kontras teks utama memenuhi WCAG AA (4.5:1)', () {
    for (final palette in <AppPalette>[AppPalette.light, AppPalette.dark]) {
      expect(
        _contrast(palette.textPrimary, palette.background),
        greaterThanOrEqualTo(4.5),
        reason: 'textPrimary/background',
      );
      expect(
        _contrast(palette.textSecondary, palette.background),
        greaterThanOrEqualTo(4.5),
        reason: 'textSecondary/background',
      );
    }
  });

  test('tombol memenuhi target sentuh minimal 44dp', () async {
    expect(appMinTouchTarget, 44);
    final theme = AppTheme.light();
    expect(
      theme.elevatedButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(0, appMinTouchTarget),
    );
  });

  testWidgets('tombol dan kartu step punya tinggi sentuh >= 44', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scaled(const AppButton(label: 'Jalankan', onPressed: _noop)),
    );
    expect(
      tester.getSize(find.byType(ElevatedButton)).height,
      greaterThanOrEqualTo(appMinTouchTarget),
    );

    await tester.pumpWidget(
      _scaled(
        const Padding(
          padding: EdgeInsets.all(16),
          child: StepCard(name: 'XOR', category: 'Crypto'),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(StepCard)).height,
      greaterThanOrEqualTo(appMinTouchTarget),
    );
  });

  testWidgets('tidak overflow pada text scale 1.3x', (tester) async {
    await tester.pumpWidget(_scaled(const AppShell()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _scaled(
        const Padding(
          padding: EdgeInsets.all(16),
          child: StepCard(
            name: 'Reverse Text',
            category: 'Utility',
            tier: 'dsl',
            errorMessage: 'Contoh error panjang agar baris membungkus.',
            state: StepCardState.error,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _scaled(
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Belum ada recipe',
          description: 'Buat recipe pertamamu untuk mulai meracik data.',
          actionLabel: 'Buat recipe baru',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('step card punya label semantik', (tester) async {
    await tester.pumpWidget(
      _scaled(const StepCard(name: 'Base64 Decode', category: 'Encode/Decode')),
    );

    expect(find.bySemanticsLabel(RegExp('Base64 Decode')), findsOneWidget);
  });
}

void _noop() {}
