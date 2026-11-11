import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';
import 'recipe.dart';

/// Recipe terbaru (urut update terakhir).
final recentRecipesProvider = FutureProvider<List<Recipe>>(
  (ref) => ref.watch(recipeRepositoryProvider).list(),
);

/// Hasil pencarian nama recipe. Query kosong = semua recipe.
final recipeSearchProvider = FutureProvider.family<List<Recipe>, String>(
  (ref, query) => ref.watch(recipeRepositoryProvider).list(query: query),
);
