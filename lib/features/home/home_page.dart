import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/localized_error.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/ui/components/app_toast.dart';
import '../../core/ui/components/empty_state.dart';
import '../../core/ui/design_tokens.dart';
import '../recipe/recipe.dart';
import '../recipe/recipe_editor_page.dart';
import '../recipe/recipe_id.dart';
import '../recipe/recipe_providers.dart';

/// Halaman Home sesuai `DESIGN.md` §8.1.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _query.isEmpty
        ? ref.watch(recentRecipesProvider)
        : ref.watch(recipeSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Bufferite')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: context.tr('home.searchHint'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: FilledButton.icon(
              onPressed: _startNewRecipe,
              icon: const Icon(Icons.add, size: 20),
              label: Text(context.tr('home.newRecipe')),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              _query.isEmpty
                  ? context.tr('home.recent')
                  : context.tr('home.searchResults'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: recipes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => EmptyState(
                icon: Icons.error_outline,
                title: context.tr('home.loadFailed'),
                description: context.trErrorObject(error),
              ),
              data: (items) => _list(items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return EmptyState(
        icon: Icons.science_outlined,
        title: _query.isEmpty
            ? context.tr('home.emptyTitle')
            : context.tr('home.noMatchTitle'),
        description: _query.isEmpty
            ? context.tr('home.emptyDescription')
            : context.tr('home.noMatchDescription'),
        actionLabel: _query.isEmpty ? context.tr('home.createFirst') : null,
        onAction: _query.isEmpty ? _startNewRecipe : null,
      );
    }

    final now = DateTime.now();
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: recipes.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return Dismissible(
          key: ValueKey<String>(recipe.id),
          direction: DismissDirection.endToStart,
          background: _dismissBackground(),
          confirmDismiss: (direction) => _confirmDelete(recipe),
          onDismissed: (direction) => _deleteRecipe(recipe),
          child: _RecipeTile(
            recipe: recipe,
            now: now,
            onTap: () => _openEditor(recipe),
            onDuplicate: () => _duplicateRecipe(recipe),
          ),
        );
      },
    );
  }

  Widget _dismissBackground() {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Icon(Icons.delete_outline, color: palette.danger),
    );
  }

  void _startNewRecipe() {
    _openEditor();
  }

  void _openEditor([Recipe? recipe]) {
    Navigator.of(context)
        .push<Recipe>(
          MaterialPageRoute<Recipe>(
            builder: (context) => RecipeEditorPage(recipe: recipe),
          ),
        )
        .then((saved) {
          if (saved != null && mounted) {
            _invalidate();
          }
        });
  }

  Future<bool> _confirmDelete(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('home.deleteTitle')),
        content: Text(
          context.tr('home.deleteBody', args: <String, Object?>{
            'name': recipe.name,
          }),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final repository = ref.read(recipeRepositoryProvider);
    await repository.delete(recipe.id);
    _invalidate();
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: context.tr('home.deleted'),
      tone: AppToastTone.warning,
      undoLabel: context.tr('common.undo'),
      onUndo: () {
        repository.save(recipe).then((_) => _invalidate());
      },
    );
  }

  Future<void> _duplicateRecipe(Recipe recipe) async {
    final repository = ref.read(recipeRepositoryProvider);
    await repository.save(duplicateRecipe(recipe));
    _invalidate();
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: context.tr('home.duplicated'),
      tone: AppToastTone.success,
    );
  }

  void _invalidate() {
    ref.invalidate(recentRecipesProvider);
    ref.invalidate(recipeSearchProvider);
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({
    required this.recipe,
    required this.now,
    required this.onTap,
    required this.onDuplicate,
  });

  final Recipe recipe;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = recipe.steps.length;
    return Card(
      child: ListTile(
        title: Text(recipe.name),
        subtitle: Text(
          context.trPlural(
            'home.recipeMeta',
            steps,
            args: <String, Object?>{
              'steps': steps,
              'time': _relativeTime(recipe, now, context),
            },
          ),
        ),
        onTap: onTap,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'duplicate') {
              onDuplicate();
            }
          },
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'duplicate',
              child: Text(context.tr('home.duplicate')),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _relativeTime(Recipe recipe, DateTime now, BuildContext context) {
  final updated = recipe.meta?.updatedAt;
  if (updated == null) {
    return context.tr('home.relative.new');
  }
  final diff = now.toUtc().difference(updated.toUtc());
  if (diff.inMinutes < 1) {
    return context.tr('home.relative.justNow');
  }
  if (diff.inHours < 1) {
    return context.trPlural('home.relative.minutes', diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return context.trPlural('home.relative.hours', diff.inHours);
  }
  if (diff.inDays == 1) {
    return context.tr('home.relative.yesterday');
  }
  if (diff.inDays < 30) {
    return context.trPlural('home.relative.days', diff.inDays);
  }
  final local = updated.toLocal();
  return '${local.year}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
