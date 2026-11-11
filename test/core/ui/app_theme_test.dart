import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palet light dan dark sesuai DESIGN.md', () {
    expect(AppPalette.light.background, const Color(0xFFFFFFFF));
    expect(AppPalette.light.accent, const Color(0xFF2563EB));
    expect(AppPalette.light.border, const Color(0xFFE4E4E7));

    expect(AppPalette.dark.background, const Color(0xFF09090B));
    expect(AppPalette.dark.accent, const Color(0xFF3B82F6));
    expect(AppPalette.dark.textPrimary, const Color(0xFFFAFAFA));
  });

  test('spacing dan radius mengikuti skala', () {
    expect(AppSpacing.xs, 4);
    expect(AppSpacing.lg, 16);
    expect(AppSpacing.xxxl, 48);
    expect(AppRadius.small, 8);
    expect(AppRadius.medium, 12);
    expect(AppRadius.pill, 999);
    expect(appMinTouchTarget, 44);
  });

  test('AppTheme.light menghasilkan color scheme dan tipografi', () {
    final theme = AppTheme.light();

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppPalette.light.accent);
    expect(theme.scaffoldBackgroundColor, AppPalette.light.background);
    expect(theme.textTheme.headlineSmall?.fontSize, 22);
    expect(theme.textTheme.bodyLarge?.fontSize, 15);
    expect(
      theme.elevatedButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(0, appMinTouchTarget),
    );
  });

  test('AppTheme.dark menghasilkan color scheme gelap', () {
    final theme = AppTheme.dark();

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppPalette.dark.accent);
    expect(theme.scaffoldBackgroundColor, AppPalette.dark.background);
  });

  testWidgets('widget memakai warna aksen tema', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => ColoredBox(
            key: const Key('surface'),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );

    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('surface'))).color,
      AppPalette.light.accent,
    );
  });
}
