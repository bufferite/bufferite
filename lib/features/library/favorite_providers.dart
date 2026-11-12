import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';
import 'favorite_repository.dart';

final favoriteRepositoryProvider = Provider<FavoriteRepository>(
  (ref) => FavoriteRepository(ref.watch(appDatabaseProvider)),
);

/// Daftar operasi favorit, persisten via SQLite.
final favoritesProvider =
    AsyncNotifierProvider<FavoritesController, Set<String>>(
      FavoritesController.new,
    );

class FavoritesController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    return (await ref.watch(favoriteRepositoryProvider).list()).toSet();
  }

  Future<void> toggle(String operationId) async {
    final repository = ref.read(favoriteRepositoryProvider);
    final current = Set<String>.of(state.value ?? const <String>{});
    final isFavorite = current.contains(operationId);
    if (isFavorite) {
      await repository.remove(operationId);
      current.remove(operationId);
    } else {
      await repository.add(operationId);
      current.add(operationId);
    }
    state = AsyncData(Set<String>.unmodifiable(current));
  }
}
