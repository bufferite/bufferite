import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/features/library/favorite_providers.dart';
import 'package:bufferite/features/library/library_page.dart';
import 'package:bufferite/features/operations/operation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/support/fake_operations.dart';

class _FakeFavorites extends FavoritesController {
  @override
  Future<Set<String>> build() async => const <String>{};
}

OperationRegistry _registry() {
  final registry = OperationRegistry();
  registry.registerOperation(
    const ReverseTextOperation(),
    pluginId: 'com.test.pack',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  registry.registerOperation(
    const Base64DecodeOperation(),
    pluginId: 'com.test.pack',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  return registry;
}

Widget _host({required OperationRegistry registry}) {
  return ProviderScope(
    overrides: [
      operationRegistryProvider.overrideWithValue(registry),
      favoritesProvider.overrideWith(_FakeFavorites.new),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: const LibraryPage()),
  );
}

void main() {
  testWidgets('menampilkan operasi dan memfilter lewat pencarian', (
    tester,
  ) async {
    await tester.pumpWidget(_host(registry: _registry()));
    await tester.pump();

    expect(find.text('Reverse Text'), findsOneWidget);
    expect(find.text('Base64 Decode'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'base');
    await tester.pump();

    expect(find.text('Base64 Decode'), findsOneWidget);
    expect(find.text('Reverse Text'), findsNothing);
  });

  testWidgets('tap operasi menampilkan detail singkat', (tester) async {
    await tester.pumpWidget(_host(registry: _registry()));
    await tester.pump();

    await tester.tap(find.text('Reverse Text'));
    await tester.pumpAndSettle();

    expect(find.text('test.reverse'), findsOneWidget);
  });

  testWidgets('tanpa plugin menampilkan empty state ke Plugin Manager', (
    tester,
  ) async {
    await tester.pumpWidget(_host(registry: OperationRegistry()));
    await tester.pump();

    expect(find.text('Belum ada operasi'), findsOneWidget);
    await tester.tap(find.text('Buka Plugin Manager'));
    await tester.pumpAndSettle();

    expect(find.text('Plugin Manager'), findsOneWidget);
  });
}
