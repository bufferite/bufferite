import 'dart:convert';
import 'dart:io';

import 'package:bufferite/core/operations/core_operations.dart';
import 'package:bufferite/core/plugin/operation.dart';

import 'core_package_builder.dart';

/// Build `core.berp` dari `plugins/core/`.
///
/// Manifest dan entrypoint DSL dibuat ulang dari `coreOperations` agar tidak
/// ada daftar operasi ganda. Hasil juga disalin ke `assets/core.berp` supaya
/// ikut terpasang bersama aplikasi.
///
/// Jalankan: `dart run tool/build_core_berp.dart`
void main(List<String> args) {
  final source = Directory('plugins/core');
  if (!source.existsSync()) {
    stderr.writeln('Folder plugins/core tidak ditemukan.');
    exitCode = 1;
    return;
  }

  _writeGeneratedFiles(source);

  final output = Directory('build');
  final result = const CorePackageBuilder().buildTo(source, output);

  final assets = Directory('assets')..createSync(recursive: true);
  File('${assets.path}/core.berp').writeAsBytesSync(result.archiveBytes);

  stdout.writeln('core.berp dibuat (${result.archiveBytes.length} byte)');
  for (final file in result.files) {
    stdout.writeln('  - $file');
  }
  stdout.writeln('SHA-256: ${result.sha256}');
}

void _writeGeneratedFiles(Directory source) {
  final operationsJson = <Map<String, Object?>>[
    for (final operation in coreOperations) _operationToJson(operation),
  ];

  final manifestFile = File('${source.path}/manifest/core.manifest.json');
  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
  manifest['operations'] = operationsJson;
  manifestFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );

  final entrypoint = File('${source.path}/operations.json');
  entrypoint.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{'operations': operationsJson})}\n',
  );
}

Map<String, Object?> _operationToJson(Operation operation) {
  return <String, Object?>{
    'id': operation.id,
    'name': operation.name,
    'category': operation.category.label,
    'params': operation.params.map((param) => param.toJson()).toList(),
    'inputType': operation.io.input.name,
    'outputType': operation.io.output.name,
  };
}
