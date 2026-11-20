import 'dart:convert';
import 'dart:io';

import 'package:bufferite/core/registry/registry_signature.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trust store produksi memuat kunci indeks dan paket aktif', () {
    final store = RegistryTrustStore.fromBytes(
      File('assets/registry_keys.json').readAsBytesSync(),
    );

    final index = store.require('official-index-2026-11', usage: 'index');
    final package = store.require('official-package-2026-11', usage: 'package');

    expect(index.publicKey, hasLength(32));
    expect(package.publicKey, hasLength(32));
    expect(index.usage, 'index');
    expect(package.usage, 'package');
    expect(store.keys.every((key) => key.isActive), isTrue);
  });

  test('trust store aplikasi dan scaffold identik', () {
    final app = File('assets/registry_keys.json').readAsStringSync();
    final scaffold = File(
      'registry-scaffold/keys/registry_keys.json',
    ).readAsStringSync();

    expect(scaffold, app);
  });

  testWidgets('aset trust store dapat dimuat rootBundle', (tester) async {
    final source = await rootBundle.loadString('assets/registry_keys.json');
    final store = RegistryTrustStore.fromBytes(utf8.encode(source));

    expect(store.keys, hasLength(2));
    expect(
      store.keys.map((key) => key.keyId),
      containsAll(<String>[
        'official-index-2026-11',
        'official-package-2026-11',
      ]),
    );
  });
}
