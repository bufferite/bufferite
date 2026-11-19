import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/i18n/app_localizations.dart';
import 'package:bufferite/core/i18n/localized_error.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

AppError _error(
  String code, {
  Map<String, Object?> details = const <String, Object?>{},
  String message = 'pesan asli',
}) {
  return AppError(
    category: ErrorCategory.validation,
    code: code,
    message: message,
    details: details,
  );
}

void main() {
  setUpAll(() async {
    await AppLocalizations.preload();
  });

  final id = AppLocalizations.forLocale(const Locale('id'));
  final en = AppLocalizations.forLocale(const Locale('en'));

  test('error validasi nama recipe memakai detail max', () {
    final error = _error(
      'recipe.invalid',
      details: <String, Object?>{'field': 'name', 'max': 120},
    );

    expect(localizedErrorFor(id, error), 'Nama recipe harus 1–120 karakter.');
    expect(
      localizedErrorFor(en, error),
      'Recipe name must be 1–120 characters.',
    );
  });

  test('error step duplikat memakai subkey duplicate', () {
    final error = _error(
      'recipe.invalid',
      details: <String, Object?>{
        'field': 'steps.id',
        'duplicate': true,
        'stepId': 'step-1',
      },
    );

    expect(localizedErrorFor(id, error), 'ID step duplikat: step-1');
    expect(localizedErrorFor(en, error), 'Duplicate step ID: step-1');
  });

  test('error parameter memilih varian min, max, dan select', () {
    expect(
      localizedErrorFor(
        en,
        _error(
          'operation.param_out_of_range',
          details: <String, Object?>{'label': 'Shift', 'min': 0},
        ),
      ),
      'Parameter "Shift" must be at least 0.',
    );
    expect(
      localizedErrorFor(
        id,
        _error(
          'operation.param_out_of_range',
          details: <String, Object?>{'label': 'Shift', 'max': 10},
        ),
      ),
      'Parameter "Shift" maksimal 10.',
    );
    expect(
      localizedErrorFor(
        en,
        _error(
          'operation.param_out_of_range',
          details: <String, Object?>{'label': 'Mode', 'value': 'x'},
        ),
      ),
      '"x" is not a valid option for "Mode".',
    );
  });

  test('error parameter wajib memakai label yang dilokalkan', () {
    expect(
      localizedErrorFor(
        en,
        _error(
          'operation.param_required',
          details: <String, Object?>{'param': 'key', 'label': 'Key'},
        ),
      ),
      'Parameter "Key" is required.',
    );
  });

  test('kode tanpa terjemahan jatuh ke pesan asli', () {
    final error = _error('plugin.unknown_failure', message: 'Plugin rusak.');

    expect(localizedErrorFor(en, error), 'Plugin rusak.');
  });

  test('label parameter diterjemahkan lewat operationId', () {
    final error = _error(
      'operation.param_required',
      details: <String, Object?>{'param': 'find', 'label': 'Cari'},
    );

    expect(
      localizedErrorFor(en, error, operationId: 'core.find_replace'),
      'Parameter "Find" is required.',
    );
  });

  test('varian error JSON memakai subkey not_object', () {
    final error = _error(
      'recipe.invalid_json',
      details: <String, Object?>{'variant': 'not_object'},
    );

    expect(localizedErrorFor(id, error), 'Recipe harus berupa objek JSON.');
    expect(localizedErrorFor(en, error), 'Recipe must be a JSON object.');
  });

  test('error ukuran recipe memakai detail maxBytes', () {
    final error = _error(
      'recipe.too_large',
      details: <String, Object?>{'maxBytes': 1024},
    );

    expect(
      localizedErrorFor(en, error),
      'Recipe size exceeds the 1024-byte limit.',
    );
  });

  test('error aset core memakai assetPath dan varian empty', () {
    final missing = _error(
      'core.asset_missing',
      details: <String, Object?>{'assetPath': 'assets/core.berp'},
    );
    final empty = _error(
      'core.asset_missing',
      details: <String, Object?>{
        'assetPath': 'assets/core.berp',
        'variant': 'empty',
      },
    );

    expect(
      localizedErrorFor(en, missing),
      'Asset assets/core.berp was not found in the app.',
    );
    expect(
      localizedErrorFor(en, empty),
      'Asset assets/core.berp is empty.',
    );
  });
}
