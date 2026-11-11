import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/home/home_page.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _recipe({required String id, required String name, int steps = 1}) {
  return Recipe(
    id: id,
    name: name,
    steps: <RecipeStep>[
      for (var index = 0; index < steps; index++)
        RecipeStep(id: 'step-$id-$index', operationId: 'core.reverse'),
    ],
    input: const TextBuffer('halo'),
    meta: RecipeMeta(updatedAt: DateTime.now().toUtc()),
  );
}

Widget _host(List<Recipe> recipes) {
  return ProviderScope(
    overrides: [
      recentRecipesProvider.overrideWith((ref) => recipes),
      recipeSearchProvider.overrideWith(
        (ref, query) => recipes
            .where(
              (recipe) =>
                  recipe.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList(),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: const HomePage()),
  );
}

void main() {
  testWidgets('empty state saat belum ada recipe', (tester) async {
    await tester.pumpWidget(_host(const <Recipe>[]));
    await tester.pump();

    expect(find.text('Belum ada recipe'), findsOneWidget);
    expect(find.text('Buat recipe baru'), findsOneWidget);
  });

  testWidgets('menampilkan recipe terbaru dan jumlah langkah', (tester) async {
    await tester.pumpWidget(
      _host(<Recipe>[
        _recipe(id: 'a', name: 'Alpha', steps: 2),
        _recipe(id: 'b', name: 'Beta'),
      ]),
    );
    await tester.pump();

    expect(find.text('Recipe Terbaru'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.textContaining('2 langkah'), findsOneWidget);
    expect(find.textContaining('1 langkah'), findsOneWidget);
  });

  testWidgets('pencarian memfilter daftar', (tester) async {
    await tester.pumpWidget(
      _host(<Recipe>[
        _recipe(id: 'a', name: 'Base64 Decode'),
        _recipe(id: 'b', name: 'Hex Encode'),
      ]),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'base');
    await tester.pump();
    await tester.pump();

    expect(find.text('Hasil Pencarian'), findsOneWidget);
    expect(find.text('Base64 Decode'), findsOneWidget);
    expect(find.text('Hex Encode'), findsNothing);
  });

  testWidgets('pencarian tanpa hasil menampilkan empty state', (tester) async {
    await tester.pumpWidget(_host(const <Recipe>[]));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    await tester.pump();

    expect(find.text('Tidak ada recipe cocok'), findsOneWidget);
  });

  testWidgets('aksi buat baru membuka editor', (tester) async {
    await tester.pumpWidget(_host(const <Recipe>[]));
    await tester.pump();

    await tester.tap(find.text('Buat recipe baru'));
    await tester.pumpAndSettle();

    expect(find.text('Nama recipe'), findsOneWidget);
    expect(find.text('Recipe Baru'), findsWidgets);
  });

  testWidgets('tap recipe membuka editor dengan nama recipe', (tester) async {
    await tester.pumpWidget(
      _host(<Recipe>[_recipe(id: 'a', name: 'Base64 Decode')]),
    );
    await tester.pump();

    await tester.tap(find.text('Base64 Decode'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Recipe'), findsOneWidget);
    expect(find.text('Base64 Decode'), findsWidgets);
  });

  testWidgets('swipe kiri menampilkan konfirmasi hapus; Batal menutup', (
    tester,
  ) async {
    await tester.pumpWidget(_host(<Recipe>[_recipe(id: 'a', name: 'Alpha')]));
    await tester.pump();

    await tester.drag(find.text('Alpha'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Hapus recipe?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus recipe?'), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('menu tile menyediakan aksi Duplikat', (tester) async {
    await tester.pumpWidget(_host(<Recipe>[_recipe(id: 'a', name: 'Alpha')]));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Duplikat'), findsOneWidget);
  });
}
