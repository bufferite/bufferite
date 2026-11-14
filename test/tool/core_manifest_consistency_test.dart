import 'dart:convert';
import 'dart:io';

import 'package:bufferite/core/operations/core_operations.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/core_package_builder.dart';

void main() {
  test('manifest core dan executor Dart memuat operasi yang sama', () {
    final json =
        jsonDecode(
              File(
                'plugins/core/manifest/core.manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final manifest = PluginManifest.fromJson(json);

    final manifestIds = manifest.operations
        .map((operation) => operation.id)
        .toSet();
    final executorIds = coreOperationsById.keys.toSet();

    expect(manifestIds, isNotEmpty);
    expect(manifestIds, executorIds);
  });

  test('aset core.berp cocok dengan build deterministik terbaru', () {
    final result = const CorePackageBuilder().build(Directory('plugins/core'));
    final asset = File('assets/core.berp');

    expect(asset.existsSync(), isTrue);
    expect(asset.readAsBytesSync(), result.archiveBytes);
  });
}
