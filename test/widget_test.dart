import 'package:bufferite/core/bootstrap/bootstrap_provider.dart';
import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/core/storage/storage_providers.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_providers.dart';
import 'package:bufferite/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('app boots and shows empty state', (tester) async {
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          recentRecipesProvider.overrideWith((ref) => const <Recipe>[]),
          coreBootstrapProvider.overrideWith(
            (ref) async => const CoreBootstrapResult.ready(),
          ),
        ],
        child: const BufferiteApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Bufferite'), findsOneWidget);
    expect(find.text('Belum ada recipe'), findsOneWidget);
    expect(
      find.text(
        'Racik data dengan resep. Recipe builder akan tersedia '
        'setelah fondasi selesai.',
      ),
      findsOneWidget,
    );
  });
}
