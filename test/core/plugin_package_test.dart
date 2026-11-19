import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/core/plugin/plugin_package.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/plugin_fixtures.dart';

Matcher _packageError(String code) {
  return isA<AppError>()
      .having((error) => error.code, 'code', code)
      .having((error) => error.category, 'category', ErrorCategory.plugin);
}

/// Menimpa ukuran deklarasi satu entri tanpa mengubah isinya.
///
/// Dipakai untuk mensimulasikan symlink/entri dengan ukuran header palsu,
/// jalur yang membuat `ZipDecoder` mendekompilasi isi sebelum batas paket
/// sempat diperiksa.
Uint8List _patchDeclaredSize(Uint8List bytes, String name, int declaredSize) {
  final data = Uint8List.fromList(bytes);
  final view = ByteData.sublistView(data);
  final directory = ZipDirectory();
  ZipFileHeader? target;
  for (final header in directory.headers(
    InputMemoryStream(data),
    verify: true,
    files: false,
  )) {
    if (header.filename == name) {
      target = header;
    }
  }
  expect(target, isNotNull, reason: 'entri $name harus ada');
  view.setUint32(target!.localHeaderOffset + 22, declaredSize, Endian.little);

  var offset = directory.centralDirectoryOffset;
  while (offset + 46 <= data.length) {
    if (view.getUint32(offset, Endian.little) != 0x02014b50) {
      break;
    }
    final nameLength = view.getUint16(offset + 28, Endian.little);
    final extraLength = view.getUint16(offset + 30, Endian.little);
    final commentLength = view.getUint16(offset + 32, Endian.little);
    final recordName = utf8.decode(
      data.sublist(offset + 46, offset + 46 + nameLength),
    );
    if (recordName == name) {
      view.setUint32(offset + 24, declaredSize, Endian.little);
      return data;
    }
    offset += 46 + nameLength + extraLength + commentLength;
  }
  fail('central directory untuk $name tidak ditemukan');
}

void main() {
  group('PluginPackage valid', () {
    test('membaca manifest dan entrypoint', () {
      final bytes = buildPackageZip();
      final package = PluginPackage.decode(bytes);

      expect(package.manifest.pluginId, 'com.test.pack');
      expect(
        utf8.decode(package.entrypointBytes()),
        contains('return function'),
      );
      expect(package.fileNames, contains('plugin.manifest.json'));
      expect(package.fileNames, contains('main.lua'));
      expect(package.read('main.lua'), isNotNull);
      expect(package.read('missing.lua'), isNull);
    });

    test('snapshot file tidak memutasi isi paket', () {
      final package = PluginPackage.decode(buildPackageZip());
      final snapshot = package.filesSnapshot();
      snapshot['main.lua']![0] = 0;

      expect(
        utf8.decode(package.entrypointBytes()),
        startsWith('return function'),
      );
    });
  });

  group('PluginPackage keamanan', () {
    test('menolak paket kosong dan zip invalid', () {
      expect(
        () => PluginPackage.decode(Uint8List(0)),
        throwsA(_packageError('plugin.package_empty')),
      );
      expect(
        () => PluginPackage.decode(Uint8List.fromList(<int>[1, 2, 3, 4])),
        throwsA(_packageError('plugin.package_invalid')),
      );
    });

    test('menolak zip-slip dan path tidak aman', () {
      for (final path in <String>[
        '../evil.lua',
        '/absolute.lua',
        r'C:\evil.lua',
        'dir/../evil.lua',
      ]) {
        final bytes = buildPackageZip(
          extraFiles: <ArchiveFile>[ArchiveFile.string(path, 'evil')],
        );
        expect(
          () => PluginPackage.decode(bytes),
          throwsA(_packageError('plugin.package_path_invalid')),
          reason: path,
        );
      }
    });

    test('menolak symbolic link', () {
      final bytes = buildPackageZip(
        extraFiles: <ArchiveFile>[ArchiveFile.symlink('link.lua', 'main.lua')],
      );
      expect(
        () => PluginPackage.decode(bytes),
        throwsA(_packageError('plugin.package_symlink')),
      );
    });

    test('menolak symlink sebelum dekompresi walau ukuran deklarasi palsu', () {
      final bytes = buildPackageZip(
        extraFiles: <ArchiveFile>[ArchiveFile.symlink('link.lua', 'main.lua')],
      );
      final bomb = _patchDeclaredSize(bytes, 'link.lua', 2 * 1024 * 1024);

      // Tanpa pindai awal, decoder membaca symlink lebih dulu dan gagal
      // sebagai paket invalid; dengan pindai awal, symlink ditolak dari
      // central directory tanpa menyentuh isinya.
      expect(
        () => PluginPackage.decode(bomb),
        throwsA(_packageError('plugin.package_symlink')),
      );
    });

    test('menolak jumlah entri sebelum decode', () {
      final bytes = buildPackageZip(
        extraFiles: <ArchiveFile>[ArchiveFile.symlink('link.lua', 'main.lua')],
      );
      final bomb = _patchDeclaredSize(bytes, 'link.lua', 2 * 1024 * 1024);

      expect(
        () => PluginPackage.decode(
          bomb,
          limits: const PluginPackageLimits(maxEntries: 2),
        ),
        throwsA(_packageError('plugin.package_too_many_entries')),
      );
    });

    test('menolak entri duplikat tanpa memedulikan kapitalisasi', () {
      final bytes = buildPackageZip(
        extraFiles: <ArchiveFile>[ArchiveFile.string('MAIN.LUA', 'duplicate')],
      );
      expect(
        () => PluginPackage.decode(bytes),
        throwsA(_packageError('plugin.package_duplicate_entry')),
      );
    });

    test('menolak batas jumlah entri, ukuran, dan total', () {
      final bytes = buildPackageZip();
      expect(
        () => PluginPackage.decode(
          bytes,
          limits: const PluginPackageLimits(maxPackageBytes: 10),
        ),
        throwsA(_packageError('plugin.package_too_large')),
      );
      expect(
        () => PluginPackage.decode(
          bytes,
          limits: const PluginPackageLimits(maxEntries: 1),
        ),
        throwsA(_packageError('plugin.package_too_many_entries')),
      );
      expect(
        () => PluginPackage.decode(
          bytes,
          limits: const PluginPackageLimits(maxEntryBytes: 10),
        ),
        throwsA(_packageError('plugin.package_entry_too_large')),
      );
      expect(
        () => PluginPackage.decode(
          bytes,
          limits: const PluginPackageLimits(maxTotalBytes: 10),
        ),
        throwsA(_packageError('plugin.package_too_large')),
      );
      expect(
        () => PluginPackage.decode(
          bytes,
          limits: const PluginPackageLimits(maxManifestBytes: 10),
        ),
        throwsA(_packageError('plugin.manifest_too_large')),
      );
    });

    test('menolak manifest hilang atau entrypoint tidak ada', () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('main.lua', 'return input'));
      final missingManifest = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(
        () => PluginPackage.decode(missingManifest),
        throwsA(_packageError('plugin.manifest_missing')),
      );

      final missingEntrypoint = buildPackageZip(
        manifest: validManifestJson(entrypoint: 'missing.lua'),
      );
      expect(
        () => PluginPackage.decode(missingEntrypoint),
        throwsA(_packageError('plugin.entrypoint_missing')),
      );
    });

    test('meneruskan error manifest terstruktur', () {
      final bytes = buildPackageZip(
        manifest: <String, Object?>{'manifestVersion': 1},
      );
      expect(
        () => PluginPackage.decode(bytes),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.field_invalid',
          ),
        ),
      );
    });

    test('menolak paket terlalu besar sebelum decode', () {
      expect(
        () => PluginPackage.decode(
          Uint8List.fromList(List<int>.filled(20, 0)),
          limits: const PluginPackageLimits(maxPackageBytes: 10),
        ),
        throwsA(_packageError('plugin.package_too_large')),
      );
    });
  });

  group('PluginPackage fuzz', () {
    test(
      'mutasi byte deterministik hanya menghasilkan AppError terstruktur',
      () {
        final random = Random(20261120);
        final valid = buildPackageZip();
        for (var iteration = 0; iteration < 200; iteration++) {
          final mutated = Uint8List.fromList(valid);
          final flips = 1 + random.nextInt(4);
          for (var flip = 0; flip < flips; flip++) {
            mutated[random.nextInt(mutated.length)] = random.nextInt(256);
          }

          try {
            PluginPackage.decode(mutated);
          } on AppError {
            // Ditolak dengan error terstruktur; tidak ada exception mentah.
          }
        }
      },
    );
  });

  test('manifest package adalah PluginManifest', () {
    final package = PluginPackage.decode(buildPackageZip());
    expect(package.manifest, isA<PluginManifest>());
  });
}
