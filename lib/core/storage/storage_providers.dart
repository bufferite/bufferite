import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recipe/recipe_repository.dart';
import '../../features/settings/settings_repository.dart';
import '../storage/app_database.dart';

/// Database aplikasi. Override pada test/boot untuk path khusus.
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(ref.watch(appDatabaseProvider)),
);
