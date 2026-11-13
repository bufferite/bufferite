import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Audit "offline by default" (F14-T06).
///
/// Memindai `lib/` dan memastikan tidak ada API jaringan yang aktif tanpa
/// aksi pengguna. Katalog Fase 2 (belum ada) dikecualikan lewat allowlist.
void main() {
  final forbidden = <RegExp>[
    RegExp(r"import\s+'package:http/"),
    RegExp(r"import\s+'package:dio/"),
    RegExp(r'\bHttpClient\b'),
    RegExp(r'\bSocket\b'),
    RegExp(r'\bWebSocket\b'),
    RegExp(r"import\s+'dart:html'"),
  ];

  test('lib/ tidak memakai API jaringan', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final pattern in forbidden) {
          if (pattern.hasMatch(lines[i])) {
            violations.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('pubspec tidak menambah dependency jaringan', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final name in <String>['http:', 'dio:', 'web_socket']) {
      expect(pubspec.contains(name), isFalse, reason: name);
    }
  });
}
