import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/components/app_badge.dart';
import '../../core/ui/components/empty_state.dart';
import '../../core/ui/design_tokens.dart';
import '../plugins/plugin_manager_page.dart';
import 'favorite_providers.dart';
import 'operation_catalog.dart';

/// Tab Library: daftar operasi + pencarian + detail singkat.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(operationCatalogProvider);
    final favorites = ref.watch(favoritesProvider).value ?? const <String>{};
    final query = _query.trim().toLowerCase();
    final items = query.isEmpty
        ? catalog
        : catalog
              .where(
                (entry) =>
                    entry.name.toLowerCase().contains(query) ||
                    entry.operationId.toLowerCase().contains(query),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Cari operasi',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: catalog.isEmpty
                ? EmptyState(
                    icon: Icons.extension_outlined,
                    title: 'Belum ada operasi',
                    description:
                        'Pasang plugin dari file atau buka katalog untuk '
                        'menambah operasi.',
                    actionLabel: 'Buka Plugin Manager',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const PluginManagerPage(),
                      ),
                    ),
                  )
                : items.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada operasi cocok',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) => _tile(
                      items[index],
                      favorites.contains(items[index].operationId),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tile(OperationCatalogEntry entry, bool isFavorite) {
    return ListTile(
      title: Text(entry.name),
      subtitle: Text(
        entry.pluginName == null
            ? entry.entry.descriptor.category.label
            : '${entry.entry.descriptor.category.label} · ${entry.pluginName}',
      ),
      leading: AppBadge(label: entry.entry.descriptor.tier.name),
      trailing: IconButton(
        tooltip: isFavorite ? 'Hapus favorit' : 'Favorit',
        icon: Icon(isFavorite ? Icons.star : Icons.star_border),
        onPressed: () =>
            ref.read(favoritesProvider.notifier).toggle(entry.operationId),
      ),
      onTap: () => _showDetail(entry),
    );
  }

  Future<void> _showDetail(OperationCatalogEntry entry) {
    final descriptor = entry.entry.descriptor;
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              descriptor.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(descriptor.id),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                AppBadge(label: descriptor.category.label),
                AppBadge(label: descriptor.tier.name),
                if (entry.pluginName != null)
                  AppBadge(label: entry.pluginName!, tone: AppBadgeTone.accent),
                if (!entry.verified)
                  const AppBadge(
                    label: 'unverified',
                    tone: AppBadgeTone.warning,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              descriptor.isSupported
                  ? 'Parameter: ${descriptor.params.length}'
                  : 'Operasi tidak didukung runtime ini.',
            ),
          ],
        ),
      ),
    );
  }
}
