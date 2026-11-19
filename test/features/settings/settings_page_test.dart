import 'package:bufferite/core/i18n/language_provider.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/theme_provider.dart';
import 'package:bufferite/features/settings/settings_page.dart';
import 'package:bufferite/features/settings/settings_provider.dart';
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

class FakeLanguageController extends LanguageController {
  @override
  Future<AppLanguage> build() async => AppLanguage.indonesian;

  final List<AppLanguage> calls = <AppLanguage>[];

  @override
  Future<void> setLanguage(AppLanguage language) async {
    calls.add(language);
    state = AsyncData(language);
  }
}

class FakeSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => AppSettings.defaults;

  Duration? stepTimeout;
  int? memoryBytes;
  bool? optInLogging;

  @override
  Future<void> setStepTimeout(Duration timeout) async {
    stepTimeout = timeout;
  }

  @override
  Future<void> setMemoryLimitBytes(int bytes) async {
    memoryBytes = bytes;
  }

  @override
  Future<void> setOptInLogging(bool enabled) async {
    optInLogging = enabled;
    state = AsyncData(AppSettings.defaults.copyWith(optInLogging: enabled));
  }
}

late FakeSettingsController settingsController;
late FakeLanguageController languageController;

Widget _host() {
  return ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(FakeThemeController.new),
      languageProvider.overrideWith(() {
        languageController = FakeLanguageController();
        return languageController;
      }),
      settingsProvider.overrideWith(() {
        settingsController = FakeSettingsController();
        return settingsController;
      }),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: const SettingsPage()),
  );
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host());
  await tester.pump();
}

void main() {
  testWidgets('menampilkan pilihan tema, bahasa, dan sandbox', (tester) async {
    await _pump(tester);

    expect(find.text('Sistem'), findsOneWidget);
    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);
    expect(find.text('Bahasa Indonesia'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Batas waktu per operasi (ms)'), findsOneWidget);
    expect(find.text('Batas memori (MiB)'), findsOneWidget);
  });

  testWidgets('memilih bahasa memanggil setLanguage', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(languageController.calls, <AppLanguage>[AppLanguage.english]);
  });

  testWidgets('memilih tema memanggil setMode', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    expect(settingsController.optInLogging, isNull);
    expect(find.text('Gelap'), findsOneWidget);
  });

  testWidgets('menyimpan batas sandbox memanggil setter', (tester) async {
    await _pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Batas waktu per operasi (ms)'),
      '1500',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Batas memori (MiB)'),
      '32',
    );
    await tester.tap(find.text('Simpan batas sandbox'));
    await tester.pumpAndSettle();

    expect(settingsController.stepTimeout, const Duration(milliseconds: 1500));
    expect(settingsController.memoryBytes, 32 * 1024 * 1024);
  });

  testWidgets('menolak batas sandbox tidak valid', (tester) async {
    await _pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Batas waktu per operasi (ms)'),
      '0',
    );
    await tester.tap(find.text('Simpan batas sandbox'));
    await tester.pumpAndSettle();

    expect(find.text('Nilai batas harus angka positif.'), findsOneWidget);
    expect(settingsController.stepTimeout, isNull);
  });

  testWidgets('toggle log memanggil setter', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Ikut serta kirim log eksekusi'));
    await tester.pumpAndSettle();

    expect(settingsController.optInLogging, isTrue);
  });
}
