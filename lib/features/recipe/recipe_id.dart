import 'dart:math';

import 'recipe.dart';

/// Membuat ID recipe UUID v4 acak.
String generateRecipeId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int index) => bytes[index].toRadixString(16).padLeft(2, '0');
  return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
      '${hex(4)}${hex(5)}-'
      '${hex(6)}${hex(7)}-'
      '${hex(8)}${hex(9)}-'
      '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
}

/// Menyalin recipe dengan ID dan nama baru, output cache dibuang.
Recipe duplicateRecipe(Recipe source, {DateTime? now, String? id}) {
  final timestamp = (now ?? DateTime.now()).toUtc();
  final newId = id ?? generateRecipeId();
  final shortcut = newId.replaceAll('-', '').substring(0, 8);
  const suffix = ' (copy)';
  const maxBase = maxRecipeNameLength - suffix.length;
  final base = source.name.length > maxBase
      ? source.name.substring(0, maxBase)
      : source.name;

  return source.copyWith(
    id: newId,
    name: '$base$suffix',
    steps: <RecipeStep>[
      for (var index = 0; index < source.steps.length; index++)
        source.steps[index].copyWith(id: '$shortcut-$index'),
    ],
    clearOutput: true,
    meta: RecipeMeta(
      createdAt: timestamp,
      updatedAt: timestamp,
      appVersion: source.meta?.appVersion,
    ),
  );
}
