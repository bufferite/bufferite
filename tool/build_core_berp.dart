import 'dart:io';

import 'core_package_builder.dart';

/// Build `core.berp` dari `plugins/core/` ke `build/`.
///
/// Jalankan: `dart run tool/build_core_berp.dart`
void main(List<String> args) {
  final source = Directory('plugins/core');
  if (!source.existsSync()) {
    stderr.writeln('Folder plugins/core tidak ditemukan.');
    exitCode = 1;
    return;
  }

  final output = Directory('build');
  final result = const CorePackageBuilder().buildTo(source, output);

  stdout.writeln('core.berp dibuat (${result.archiveBytes.length} byte)');
  for (final file in result.files) {
    stdout.writeln('  - $file');
  }
  stdout.writeln('SHA-256: ${result.sha256}');
}
