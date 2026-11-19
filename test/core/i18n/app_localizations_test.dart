import 'package:bufferite/core/i18n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AppLocalizations.preload();
  });

  test('katalog Indonesia dan Inggris memuat terjemahan berbeda', () {
    final id = AppLocalizations.forLocale(const Locale('id'));
    final en = AppLocalizations.forLocale(const Locale('en'));

    expect(id.tr('home.newRecipe'), 'Recipe Baru');
    expect(en.tr('home.newRecipe'), 'New Recipe');
    expect(id.tr('recipe.ingredients'), 'Ingredients');
    expect(en.tr('settings.languageLabel'), 'App language');
  });

  test('interpolasi argumen dan fallback key', () {
    final id = AppLocalizations.forLocale(const Locale('id'));

    expect(
      id.tr('home.deleteBody', args: <String, Object?>{'name': 'Crypto'}),
      '"Crypto" akan dihapus.',
    );
    expect(id.tr('key.tidak.ada'), 'key.tidak.ada');
  });

  test('plural mengikuti jumlah pada bahasa Inggris', () {
    final en = AppLocalizations.forLocale(const Locale('en'));

    expect(
      en.trPlural(
        'home.recipeMeta',
        1,
        args: <String, Object?>{'steps': 1, 'time': 'now'},
      ),
      '1 step · now',
    );
    expect(
      en.trPlural(
        'home.recipeMeta',
        2,
        args: <String, Object?>{'steps': 2, 'time': 'now'},
      ),
      '2 steps · now',
    );
  });

  test('locale tidak didukung jatuh ke Indonesia', () {
    final fr = AppLocalizations.forLocale(const Locale('fr'));

    expect(fr.locale, const Locale('id'));
    expect(fr.tr('home.newRecipe'), 'Recipe Baru');
  });
}
