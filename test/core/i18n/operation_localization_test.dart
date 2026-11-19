import 'package:bufferite/core/i18n/app_localizations.dart';
import 'package:bufferite/core/operations/core_operations.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AppLocalizations.preload();
  });

  test('semua operasi inti punya nama di kedua katalog', () {
    final id = AppLocalizations.forLocale(const Locale('id'));
    final en = AppLocalizations.forLocale(const Locale('en'));

    for (final operation in coreOperations) {
      expect(
        id.trOrNull('operations.${operation.id}.name'),
        isNotNull,
        reason: 'Nama Indonesia hilang untuk ${operation.id}',
      );
      expect(
        en.trOrNull('operations.${operation.id}.name'),
        isNotNull,
        reason: 'Nama Inggris hilang untuk ${operation.id}',
      );
    }
  });

  test('semua parameter inti punya label, help, dan opsi di kedua katalog', () {
    final id = AppLocalizations.forLocale(const Locale('id'));
    final en = AppLocalizations.forLocale(const Locale('en'));

    for (final operation in coreOperations) {
      for (final param in operation.params) {
        final prefix = 'operations.${operation.id}.params.${param.key}';
        for (final localizations in <AppLocalizations>[id, en]) {
          expect(
            localizations.trOrNull('$prefix.label'),
            isNotNull,
            reason: 'Label ${param.key} hilang untuk ${operation.id}',
          );
          if (param.helpText != null) {
            expect(
              localizations.trOrNull('$prefix.help'),
              isNotNull,
              reason: 'Help ${param.key} hilang untuk ${operation.id}',
            );
          }
          for (final option in param.options) {
            expect(
              localizations.trOrNull('$prefix.options.${option.value}'),
              isNotNull,
              reason:
                  'Opsi ${option.value} hilang untuk ${operation.id}.${param.key}',
            );
          }
        }
      }
    }
  });

  test('kategori operasi diterjemahkan', () {
    final id = AppLocalizations.forLocale(const Locale('id'));
    final en = AppLocalizations.forLocale(const Locale('en'));

    for (final category in OperationCategory.values) {
      expect(id.trOrNull('operationCategory.${category.name}'), isNotNull);
      expect(en.trOrNull('operationCategory.${category.name}'), isNotNull);
    }
    expect(id.tr('operationCategory.crypto'), 'Kripto');
    expect(en.tr('operationCategory.crypto'), 'Crypto');
  });

  test('nama dan label operasi berbeda antar bahasa', () {
    final id = AppLocalizations.forLocale(const Locale('id'));
    final en = AppLocalizations.forLocale(const Locale('en'));

    expect(id.tr('operations.core.slice.name'), 'Potong');
    expect(en.tr('operations.core.slice.name'), 'Slice');
    expect(id.tr('operations.core.find_replace.params.find.label'), 'Cari');
    expect(en.tr('operations.core.find_replace.params.find.label'), 'Find');
    expect(
      en.tr('operations.core.aes_encrypt.params.mode.options.ctr'),
      'CTR (no padding)',
    );
  });
}
