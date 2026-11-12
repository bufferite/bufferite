import 'package:flutter/material.dart';

import '../../core/ui/components/empty_state.dart';

/// Placeholder Plugin Manager. Daftar plugin, sideload, dan katalog diisi F11.
class PluginManagerPage extends StatelessWidget {
  const PluginManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin Manager')),
      body: const EmptyState(
        icon: Icons.extension_outlined,
        title: 'Belum ada plugin terpasang',
        description:
            'Instal plugin dari file .berp (sideload) atau buka katalog '
            'saat tersedia.',
      ),
    );
  }
}
