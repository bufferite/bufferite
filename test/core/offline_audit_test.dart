import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Audit "offline by default" (F14-T06).
///
/// Memindai `lib/` dan memastikan tidak ada API jaringan yang aktif tanpa
/// aksi pengguna. Katalog Fase 2 hanya boleh memakai `HttpClient` di
/// `lib/core/registry/registry_transport.dart`.
void main() {
  const registryTransport = 'lib/core/registry/registry_transport.dart';
  final forbidden = <({RegExp pattern, String? allowedFile})>[
    (pattern: RegExp(r"import\s+'package:http/"), allowedFile: null),
    (pattern: RegExp(r"import\s+'package:dio/"), allowedFile: null),
    (pattern: RegExp(r'\bHttpClient\b'), allowedFile: registryTransport),
    (pattern: RegExp(r'\bSocket\b'), allowedFile: null),
    (pattern: RegExp(r'\bWebSocket\b'), allowedFile: null),
    (pattern: RegExp(r"import\s+'dart:html'"), allowedFile: null),
  ];

  test('lib/ tidak memakai API jaringan', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final relative = entity.path.replaceAll('\\', '/');
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final rule in forbidden) {
          if (rule.allowedFile != null && relative == rule.allowedFile) {
            continue;
          }
          if (rule.pattern.hasMatch(lines[i])) {
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
