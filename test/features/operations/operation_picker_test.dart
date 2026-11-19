import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/step_card.dart';
import 'package:bufferite/features/operations/operation_picker.dart';
import 'package:bufferite/features/operations/operation_providers.dart';
import 'package:bufferite/features/recipe/recipe_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/support/fake_operations.dart';

OperationRegistry _registry() {
  final registry = OperationRegistry();
  registry.registerOperation(
    const ReverseTextOperation(),
    pluginId: 'dev.bufferite.core',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  registry.registerOperation(
    const Base64DecodeOperation(),
    pluginId: 'dev.bufferite.core',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  return registry;
}

void main() {
  testWidgets('picker menampilkan dan memfilter operasi', (tester) async {
    OperationDescriptor? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showOperationPicker(
                    context,
                    registry: _registry(),
                  );
                },
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.text('Reverse Text'), findsOneWidget);
    expect(find.text('Base64 Decode'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'base64');
    await tester.pumpAndSettle();
    expect(find.text('Reverse Text'), findsNothing);

    await tester.tap(find.text('Base64 Decode'));
    await tester.pumpAndSettle();
    expect(selected?.name, 'Base64 Decode');
  });

  testWidgets('picker tanpa hasil menampilkan pesan kosong', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: OperationPicker(registry: _registry())),
      ),
    );

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada operasi cocok'), findsOneWidget);
  });

  testWidgets('chip kategori memfilter daftar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: OperationPicker(registry: _registry())),
      ),
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Encode/Decode'));
    await tester.pumpAndSettle();

    expect(find.text('Base64 Decode'), findsOneWidget);
    expect(find.text('Reverse Text'), findsNothing);
  });

  testWidgets('chip Favorit hanya menampilkan favorit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: OperationPicker(
            registry: _registry(),
            favorites: const <String>{'test.reverse'},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Favorit'));
    await tester.pumpAndSettle();

    expect(find.text('Reverse Text'), findsOneWidget);
    expect(find.text('Base64 Decode'), findsNothing);
  });

  testWidgets('editor menambah step dari picker', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [operationRegistryProvider.overrideWithValue(_registry())],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RecipeEditorPage(),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Ingredients'));
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada ingredients. Tambahkan operasi dari Library.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tambah ingredients'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reverse Text'));
    await tester.pumpAndSettle();

    expect(find.byType(StepCard), findsOneWidget);
    expect(
      find.text('Belum ada ingredients. Tambahkan operasi dari Library.'),
      findsNothing,
    );
  });
}
