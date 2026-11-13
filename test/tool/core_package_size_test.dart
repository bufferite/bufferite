import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/core_package_builder.dart';

/// F13-T11: ukuran `core.berp` dijaga di bawah target MVP.
void main() {
  test('core.berp di bawah target ukuran', () {
    const targetBytes = 2 * 1024 * 1024;
    final source = Directory('plugins/core');
    final result = const CorePackageBuilder().build(source);

    expect(result.archiveBytes.length, lessThan(targetBytes));
    expect(result.files, isNotEmpty);
  });
}
