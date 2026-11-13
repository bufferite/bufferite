import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/core_package_builder.dart';

void main() {
  late Directory root;
  late Directory source;

  setUp(() {
    root = Directory.systemTemp.createTempSync('bufferite_core_build_');
    source = Directory('${root.path}/plugins/core')
      ..createSync(recursive: true);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  void write(String path, String content) {
    final file = File('${source.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  test('build deterministik dan menghasilkan SHA-256', () {
    write('manifest/core.manifest.json', '{"pluginId":"dev.bufferite.core"}');
    write('src/util/reverse.json', '{"id":"core.reverse"}');

    const builder = CorePackageBuilder();
    final first = builder.build(source);
    final second = builder.build(source);

    expect(first.sha256, hasLength(64));
    expect(first.sha256, second.sha256);
    expect(first.archiveBytes, second.archiveBytes);
    expect(first.files, <String>[
      'plugin.manifest.json',
        'src/util/reverse.json',
    ]);
  });

  test('README dan file hash dikeluarkan dari paket', () {
    write('README.md', 'docs');
    write('manifest/core.manifest.json', '{}');
    write('core.berp.sha256', 'abc');

    const builder = CorePackageBuilder();
    final result = builder.build(source);

    expect(result.files, <String>['plugin.manifest.json']);
  });

  test('buildTo menulis arsip dan hash', () {
    write('manifest/core.manifest.json', '{}');
    final output = Directory('${root.path}/build');

    const builder = CorePackageBuilder();
    final result = builder.buildTo(source, output);

    expect(File('${output.path}/core.berp').existsSync(), isTrue);
    expect(
      File('${output.path}/core.berp.sha256').readAsStringSync().trim(),
      result.sha256,
    );
  });

  test('readManifest membaca manifest bila ada', () {
    write('manifest/core.manifest.json', '{"pluginId":"dev.bufferite.core"}');

    expect(readManifest(source)['pluginId'], 'dev.bufferite.core');
    expect(readManifest(Directory('${root.path}/empty'))['pluginId'], isNull);
  });
}
