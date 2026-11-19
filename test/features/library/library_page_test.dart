import 'package:bufferite/core/i18n/app_localizations.dart';
import 'package:bufferite/core/operations/core_operations.dart';
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
  _FakeFavorites(this._values);

  final Set<String> _values;

  @override
  Future<Set<String>> build() async => _values;
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

Widget _host({
  required OperationRegistry registry,
  Set<String> favorites = const <String>{},
  bool english = false,
}) {
  final app = MaterialApp(theme: AppTheme.light(), home: const LibraryPage());
  return ProviderScope(
    overrides: [
      operationRegistryProvider.overrideWithValue(registry),
      favoritesProvider.overrideWith(() => _FakeFavorites(favorites)),
    ],
    child: english
        ? AppLocalizationsScope(
            localizations: AppLocalizations.forLocale(const Locale('en')),
            child: app,
          )
        : app,
  );
}

OperationRegistry _coreRegistry() {
  final registry = OperationRegistry();
  for (final operation in coreOperations) {
    registry.registerOperation(
      operation,
      pluginId: 'dev.bufferite.core',
      pluginVersion: '1.0.0',
      tier: RuntimeTier.dsl,
    );
  }
  return registry;
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

  testWidgets('tombol kelola plugin selalu tersedia di AppBar', (tester) async {
    await tester.pumpWidget(_host(registry: _registry()));
    await tester.pump();

    await tester.tap(find.byTooltip('Kelola plugin'));
    await tester.pumpAndSettle();

    expect(find.text('Plugin Manager'), findsOneWidget);
  });

  testWidgets('chip kategori memfilter operasi', (tester) async {
    await tester.pumpWidget(_host(registry: _registry()));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilterChip, 'Encode/Decode'));
    await tester.pump();

    expect(find.text('Base64 Decode'), findsOneWidget);
    expect(find.text('Reverse Text'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Semua'));
    await tester.pump();

    expect(find.text('Reverse Text'), findsOneWidget);
    expect(find.text('Base64 Decode'), findsOneWidget);
  });

  testWidgets('chip favorit hanya menampilkan operasi favorit', (tester) async {
    await tester.pumpWidget(
      _host(registry: _registry(), favorites: <String>{'test.reverse'}),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilterChip, 'Favorit'));
    await tester.pump();

    expect(find.text('Reverse Text'), findsOneWidget);
    expect(find.text('Base64 Decode'), findsNothing);
  });

  testWidgets('favorit kosong menampilkan pesan khusus', (tester) async {
    await tester.pumpWidget(_host(registry: _registry()));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilterChip, 'Favorit'));
    await tester.pump();

    expect(find.text('Belum ada operasi favorit'), findsOneWidget);
  });

  testWidgets('metadata operasi inti mengikuti bahasa Inggris', (tester) async {
    await tester.pumpWidget(_host(registry: _coreRegistry(), english: true));
    await tester.pump();

    expect(find.widgetWithText(FilterChip, 'Crypto'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'slice');
    await tester.pump();

    expect(find.text('Slice'), findsOneWidget);
    expect(find.text('Potong'), findsNothing);
  });
}
