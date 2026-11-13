import 'dart:io';

import 'package:bufferite/core/plugin/plugin_integrity.dart';
import 'package:bufferite/core/plugin/plugin_package.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/core_package_builder.dart';

void main() {
  late Directory root;
  late Directory source;

  setUp(() {
    root = Directory.systemTemp.createTempSync('bufferite_core_integrity_');
    source = Directory('${root.path}/plugins/core')
      ..createSync(recursive: true);
    final manifest = File('${source.path}/manifest/core.manifest.json')
      ..parent.createSync(recursive: true);
    manifest.writeAsStringSync(
      '{"manifestVersion":1,"pluginId":"dev.bufferite.core",'
      '"name":"Bufferite Core","version":"1.0.0","minAppVersion":"1.0.0",'
      '"tier":"dsl","entrypoint":"operations.json","permissions":["cpu"],'
      '"operations":[{"id":"core.noop","name":"No-op","category":"Utility",'
      '"params":[],"inputType":"text","outputType":"text"}]}',
    );
    final operations = File('${source.path}/operations.json')
      ..writeAsStringSync('{"schemaVersion":1,"operations":[]}');
    // Entrypoint harus ada di dalam paket.
    operations.writeAsStringSync('{"schemaVersion":1,"operations":[]}');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('hash hasil build cocok dengan verifikator aplikasi', () {
    const builder = CorePackageBuilder();
    final result = builder.build(source);

    // Tidak melempar = verifikasi aplikasi menerima hash build.
    PluginIntegrity.verifyOrThrow(
      bytes: result.archiveBytes,
      expected: result.sha256,
      subject: 'core.berp',
    );
  });

  test('build ulang menghasilkan byte dan hash yang sama', () {
    const builder = CorePackageBuilder();
    final first = builder.build(source);
    final second = builder.build(source);

    expect(second.archiveBytes, first.archiveBytes);
    expect(second.sha256, first.sha256);
  });

  test('arsip hasil build tervalidasi oleh PluginPackage.decode', () {
    const builder = CorePackageBuilder();
    final result = builder.build(source);

    final package = PluginPackage.decode(result.archiveBytes);
    expect(package.manifest.pluginId, 'dev.bufferite.core');
    expect(package.entrypointBytes(), isNotEmpty);
  });

  test('modifikasi satu byte membuat verifikasi gagal', () {
    const builder = CorePackageBuilder();
    final result = builder.build(source);
    final tampered = List<int>.of(result.archiveBytes);
    tampered[tampered.length - 1] ^= 0xFF;

    expect(
      () => PluginIntegrity.verifyOrThrow(
        bytes: tampered,
        expected: result.sha256,
        subject: 'core.berp',
      ),
      throwsA(
        isA<Object>().having(
          (error) => '$error',
          'message',
          contains('plugin'),
        ),
      ),
    );
  });

  test('menulis file hash dan isinya cocok dengan build ulang', () {
    const builder = CorePackageBuilder();
    final output = Directory('${root.path}/build');
    final first = builder.buildTo(source, output);

    final written = File(
      '${output.path}/core.berp.sha256',
    ).readAsStringSync().trim();
    expect(written, first.sha256);

    final second = builder.build(source);
    expect(second.sha256, written);
  });
}
