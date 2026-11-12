import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/theme_provider.dart';
import 'package:bufferite/features/settings/settings_page.dart';
import 'package:bufferite/features/settings/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeThemeController extends ThemeModeController {
  @override
  Future<AppThemeMode> build() async => AppThemeMode.system;

  final List<AppThemeMode> calls = <AppThemeMode>[];

  @override
  Future<void> setMode(AppThemeMode mode) async {
    calls.add(mode);
    state = AsyncData(mode);
  }
}

void main() {
  testWidgets('menampilkan tiga pilihan tema', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [themeModeProvider.overrideWith(FakeThemeController.new)],
        child: MaterialApp(theme: AppTheme.light(), home: const SettingsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Sistem'), findsOneWidget);
    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);
  });

  testWidgets('memilih tema memanggil setMode', (tester) async {
    late FakeThemeController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith(() {
            controller = FakeThemeController();
            return controller;
          }),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const SettingsPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    expect(controller.calls, <AppThemeMode>[AppThemeMode.dark]);
  });
}
