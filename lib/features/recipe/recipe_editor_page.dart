import 'package:flutter/material.dart';

import '../../core/ui/components/empty_state.dart';
import 'recipe.dart';

/// Placeholder Recipe Editor. Layout penuh diisi pada F09.
class RecipeEditorPage extends StatelessWidget {
  const RecipeEditorPage({super.key, this.recipe});

  final Recipe? recipe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(recipe?.name ?? 'Recipe Baru')),
      body: const EmptyState(
        icon: Icons.edit_note,
        title: 'Editor recipe',
        description: 'Layout, step, dan input akan diisi pada F09.',
      ),
    );
  }
}
