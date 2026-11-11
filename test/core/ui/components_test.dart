import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/app_badge.dart';
import 'package:bufferite/core/ui/components/app_button.dart';
import 'package:bufferite/core/ui/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('primary memanggil onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Jalankan', onPressed: () => taps++)),
      );

      await tester.tap(find.text('Jalankan'));
      expect(taps, 1);
    });

    testWidgets('loading menonaktifkan tombol', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppButton(label: 'Simpan', loading: true, onPressed: () => taps++),
        ),
      );

      await tester.tap(find.text('Simpan'));
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('disabled saat onPressed null', (tester) async {
      await tester.pumpWidget(_host(const AppButton(label: 'Nonaktif')));
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('varian danger memakai warna danger', (tester) async {
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Hapus',
            variant: AppButtonVariant.danger,
            onPressed: () {},
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final color = button.style?.backgroundColor?.resolve(<WidgetState>{});
      expect(color, AppPalette.light.danger);
    });

    testWidgets('expand mengisi lebar', (tester) async {
      await tester.pumpWidget(
        _host(AppButton(label: 'Lebar', expand: true, onPressed: () {})),
      );

      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('AppBadge', () {
    testWidgets('menampilkan label dan ikon', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppBadge(
            label: 'lua',
            tone: AppBadgeTone.accent,
            icon: Icons.bolt,
          ),
        ),
      );

      expect(find.text('lua'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('tone warning memakai warna warning', (tester) async {
      await tester.pumpWidget(
        _host(const AppBadge(label: 'unverified', tone: AppBadgeTone.warning)),
      );

      final text = tester.widget<Text>(find.text('unverified'));
      expect(text.style?.color, AppPalette.light.warning);
    });
  });
}
