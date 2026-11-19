import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import 'design_tokens.dart';

/// App shell dengan bottom navigation 3 tab.
///
/// Memakai [IndexedStack] agar state tiap tab terjaga saat berpindah.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.home = const HomePlaceholder(),
    this.library = const LibraryPlaceholder(),
    this.settings = const SettingsPlaceholder(),
  });

  /// Widget tab Home. Default placeholder sampai F08; komposisi nyata di
  /// `main.dart`.
  final Widget home;

  /// Widget tab Library. Default placeholder sampai F10.
  final Widget library;

  /// Widget tab Settings. Default placeholder sampai F12.
  final Widget settings;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[widget.home, widget.library, widget.settings],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: context.tr('nav.home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.grid_view_outlined),
            activeIcon: const Icon(Icons.grid_view),
            label: context.tr('nav.library'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: context.tr('nav.settings'),
          ),
        ],
      ),
    );
  }
}

/// Placeholder Home sampai F08.
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bufferite')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.science_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                context.tr('shell.emptyTitle'),
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.tr('shell.emptyDescription'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder Library sampai F10.
class LibraryPlaceholder extends StatelessWidget {
  const LibraryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.library'))),
      body: Center(child: Text(context.tr('shell.catalog'))),
    );
  }
}

/// Placeholder Settings sampai F12.
class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.settings'))),
      body: Center(child: Text(context.tr('shell.settingsBody'))),
    );
  }
}
