import 'dart:async';

import 'package:bufferite/core/i18n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Memuat katalog terjemahan sebelum seluruh test berjalan.
///
/// Widget yang dipompa tanpa [AppLocalizationsScope] memakai fallback
/// Indonesia dari [AppLocalizations.current].
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.preload();
  await testMain();
}
