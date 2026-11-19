import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/plugin/operation.dart';
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
  OperationCategory? _category;
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(operationCatalogProvider);
    final favorites = ref.watch(favoritesProvider).value ?? const <String>{};
    final items = _filtered(catalog, favorites);
    final categories = <OperationCategory>{
      for (final entry in catalog) entry.entry.descriptor.category,
    }.toList()..sort((a, b) => a.label.compareTo(b.label));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('nav.library')),
        actions: <Widget>[
          IconButton(
            tooltip: context.tr('library.managePlugins'),
            icon: const Icon(Icons.extension_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const PluginManagerPage(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: context.tr('library.searchHint'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          if (catalog.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: <Widget>[
                  FilterChip(
                    label: Text(context.tr('library.all')),
                    selected: _category == null && !_favoritesOnly,
                    onSelected: (_) => setState(() {
                      _category = null;
                      _favoritesOnly = false;
                    }),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilterChip(
                    label: Text(context.tr('library.favorites')),
                    selected: _favoritesOnly,
                    onSelected: (_) => setState(() {
                      _favoritesOnly = !_favoritesOnly;
                      if (_favoritesOnly) {
                        _category = null;
                      }
                    }),
                  ),
                  for (final category in categories) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    FilterChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() {
                        _category = _category == category ? null : category;
                        if (_category != null) {
                          _favoritesOnly = false;
                        }
                      }),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: catalog.isEmpty
                ? EmptyState(
                    icon: Icons.extension_outlined,
                    title: context.tr('library.emptyTitle'),
                    description: context.tr('library.emptyDescription'),
                    actionLabel: context.tr('library.openPluginManager'),
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const PluginManagerPage(),
                      ),
                    ),
                  )
                : items.isEmpty
                ? Center(
                    child: Text(
                      _emptyFilterMessage(context),
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

  List<OperationCatalogEntry> _filtered(
    List<OperationCatalogEntry> catalog,
    Set<String> favorites,
  ) {
    final query = _query.trim().toLowerCase();
    Iterable<OperationCatalogEntry> items = catalog;
    if (query.isNotEmpty) {
      items = items.where(
        (entry) =>
            entry.name.toLowerCase().contains(query) ||
            entry.operationId.toLowerCase().contains(query),
      );
    }
    final category = _category;
    if (category != null) {
      items = items.where(
        (entry) => entry.entry.descriptor.category == category,
      );
    }
    if (_favoritesOnly) {
      items = items.where((entry) => favorites.contains(entry.operationId));
    }
    return items.toList();
  }

  String _emptyFilterMessage(BuildContext context) {
    if (_favoritesOnly) {
      return context.tr('library.noFavorites');
    }
    if (_category != null) {
      return context.tr('library.noCategory');
    }
    return context.tr('library.noMatch');
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
        tooltip: isFavorite
            ? context.tr('library.favoriteRemove')
            : context.tr('library.favoriteAdd'),
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
                  AppBadge(
                    label: context.tr('common.unverified'),
                    tone: AppBadgeTone.warning,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              descriptor.isSupported
                  ? context.tr('library.params', args: <String, Object?>{
                      'count': descriptor.params.length,
                    })
                  : context.tr('library.unsupported'),
            ),
          ],
        ),
      ),
    );
  }
}
