import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: BufferiteApp()));
}

/// Root aplikasi Bufferite.
///
/// Pada Fase 0 widget ini masih berupa placeholder. App shell, tema lengkap,
/// dan navigasi akan diisi pada F07.
class BufferiteApp extends StatelessWidget {
  const BufferiteApp({super.key});

  static const _accent = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bufferite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _accent),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _BootstrapPlaceholder(),
    );
  }
}

class _BootstrapPlaceholder extends StatelessWidget {
  const _BootstrapPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bufferite')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.science_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada recipe',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Racik data dengan resep. Recipe builder akan tersedia '
                'setelah fondasi selesai.',
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
