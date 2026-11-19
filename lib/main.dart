import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap/bootstrap_gate.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/language_provider.dart';
import 'core/ui/app_shell.dart';
import 'core/ui/app_theme.dart';
import 'core/ui/theme_provider.dart';
import 'features/home/home_page.dart';
import 'features/library/library_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.preload();
  runApp(const ProviderScope(child: BufferiteApp()));
}

/// Root aplikasi Bufferite.
///
/// App shell, navigasi, dan fitur diisi pada F07+.
class BufferiteApp extends ConsumerWidget {
  const BufferiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(themeModeProvider).asData?.value ?? AppThemeMode.system;
    final language =
        ref.watch(languageProvider).asData?.value ?? AppLanguage.indonesian;
    final localizations = AppLocalizations.forLocale(Locale(language.code));

    return AppLocalizationsScope(
      localizations: localizations,
      child: MaterialApp(
        title: localizations.tr('app.title'),
        debugShowCheckedModeBanner: false,
        locale: localizations.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeModeFor(mode),
        home: const BootstrapGate(
          child: AppShell(
            home: HomePage(),
            library: LibraryPage(),
            settings: SettingsPage(),
          ),
        ),
      ),
    );
  }
}
