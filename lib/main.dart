import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ui/app_shell.dart';
import 'core/ui/app_theme.dart';
import 'core/ui/theme_provider.dart';
import 'features/home/home_page.dart';
import 'features/library/library_page.dart';
import 'features/settings/settings_repository.dart';

void main() {
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
    return MaterialApp(
      title: 'Bufferite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeModeFor(mode),
      home: const AppShell(home: HomePage(), library: LibraryPage()),
    );
  }
}
