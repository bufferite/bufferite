import 'dart:convert';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/plugin_manifest.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/plugin/semantic_version.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _validManifest() {
  return <String, Object?>{
    'manifestVersion': 1,
    'pluginId': 'com.contoh.encoding-pack',
    'name': 'Encoding Pack',
    'version': '1.2.0',
    'author': 'Komunitas',
    'description': 'Kumpulan operasi encoding.',
    'license': 'MIT',
    'homepage': 'https://example.com',
    'minAppVersion': '1.0.0',
    'tier': 'lua',
    'entrypoint': 'main.lua',
    'permissions': <Object?>['cpu'],
    'operations': <Object?>[
      <String, Object?>{
        'id': 'contoh.base32_decode',
        'name': 'Base32 Decode',
        'category': 'Encode/Decode',
        'params': <Object?>[
          <String, Object?>{
            'key': 'padding',
            'type': 'boolean',
            'default': true,
          },
        ],
        'inputType': 'bytes',
        'outputType': 'bytes',
      },
    ],
    'integrity': <String, Object?>{
      'sha256':
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      'signature': 'signature-opsional',
    },
  };
}

void main() {
  group('PluginManifest valid', () {
    test('mem-parse field, operation, dan default label parameter', () {
      final manifest = PluginManifest.fromJson(_validManifest());

      expect(manifest.pluginId, 'com.contoh.encoding-pack');
      expect(manifest.name, 'Encoding Pack');
      expect(manifest.version, SemanticVersion.parse('1.2.0'));
      expect(manifest.minAppVersion, SemanticVersion.parse('1.0.0'));
      expect(manifest.tier, RuntimeTier.lua);
      expect(manifest.entrypoint, 'main.lua');
      expect(manifest.permissions, <PluginPermission>{PluginPermission.cpu});
      expect(manifest.operations, hasLength(1));
      expect(manifest.integritySha256, startsWith('0123456789abcdef'));
      expect(manifest.operations.single.params.single.label, 'padding');
      expect(manifest.operations.single.io.input, BufferKind.bytes);
    });

    test('membuat OperationDescriptor dari manifest', () {
      final manifest = PluginManifest.fromJson(_validManifest());
      final descriptor = manifest.toOperationDescriptors().single;

      expect(descriptor.id, 'contoh.base32_decode');
      expect(descriptor.pluginId, 'com.contoh.encoding-pack');
      expect(descriptor.pluginVersion, '1.2.0');
      expect(descriptor.tier, RuntimeTier.lua);
      expect(descriptor.category, OperationCategory.encodeDecode);
      expect(descriptor.isSupported, isTrue);
    });

    test('round-trip JSON manifest', () {
      final manifest = PluginManifest.fromJson(_validManifest());
      final parsed = PluginManifest.fromJsonString(
        jsonEncode(manifest.toJson()),
      );

      expect(parsed.pluginId, manifest.pluginId);
      expect(parsed.version.toString(), '1.2.0');
      expect(parsed.operations.single.id, 'contoh.base32_decode');
      expect(parsed.permissions, manifest.permissions);
    });

    test('cek kompatibilitas minAppVersion', () {
      final manifest = PluginManifest.fromJson(_validManifest());
      expect(manifest.isCompatibleWith(SemanticVersion.parse('1.0.0')), isTrue);
      expect(manifest.isCompatibleWith(SemanticVersion.parse('1.1.0')), isTrue);
      expect(
        manifest.isCompatibleWith(SemanticVersion.parse('0.9.9')),
        isFalse,
      );
    });

    test('menambahkan cpu bila permissions tidak ditulis', () {
      final json = _validManifest()..remove('permissions');
      final manifest = PluginManifest.fromJson(json);
      expect(manifest.permissions, <PluginPermission>{PluginPermission.cpu});
    });
  });

  group('PluginManifest invalid', () {
    test('menolak manifestVersion tidak didukung atau salah tipe', () {
      expect(
        () =>
            PluginManifest.fromJson(_validManifest()..['manifestVersion'] = 2),
        throwsA(
          isA<AppError>()
              .having(
                (error) => error.code,
                'code',
                'plugin.manifest_version_unsupported',
              )
              .having(
                (error) => error.category,
                'category',
                ErrorCategory.unsupported,
              ),
        ),
      );
      expect(
        () => PluginManifest.fromJson(
          _validManifest()..['manifestVersion'] = '1',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.manifest_version_invalid',
          ),
        ),
      );
    });

    test('menolak pluginId, nama, versi, dan minAppVersion tidak valid', () {
      expect(
        () => PluginManifest.fromJson(
          _validManifest()..['pluginId'] = 'EncodingPack',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.id_invalid',
          ),
        ),
      );
      expect(
        () => PluginManifest.fromJson(_validManifest()..['name'] = ' '),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.field_invalid',
          ),
        ),
      );
      expect(
        () => PluginManifest.fromJson(_validManifest()..['version'] = '1.2'),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.version_invalid',
          ),
        ),
      );
      expect(
        () => PluginManifest.fromJson(
          _validManifest()..['minAppVersion'] = 'latest',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.version_invalid',
          ),
        ),
      );
    });

    test('menolak tier dan entrypoint tidak valid', () {
      expect(
        () => PluginManifest.fromJson(_validManifest()..['tier'] = 'python'),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.tier_invalid',
          ),
        ),
      );
      for (final entrypoint in <String>[
        '../evil.lua',
        '/abs/main.lua',
        r'C:\main.lua',
        'dir//main.lua',
        'dir\\main.lua',
        'main.json',
      ]) {
        expect(
          () => PluginManifest.fromJson(
            _validManifest()..['entrypoint'] = entrypoint,
          ),
          throwsA(
            isA<AppError>().having(
              (error) => error.code,
              'code',
              anyOf(
                'plugin.entrypoint_invalid',
                'plugin.entrypoint_tier_mismatch',
              ),
            ),
          ),
          reason: entrypoint,
        );
      }
    });

    test('menolak permissions tidak dikenal atau bukan array', () {
      expect(
        () => PluginManifest.fromJson(
          _validManifest()..['permissions'] = <Object?>['camera'],
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.permission_unknown',
          ),
        ),
      );
      expect(
        () =>
            PluginManifest.fromJson(_validManifest()..['permissions'] = 'cpu'),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.permissions_invalid',
          ),
        ),
      );
    });

    test('menolak operations hilang, kosong, atau duplikat', () {
      expect(
        () => PluginManifest.fromJson(_validManifest()..remove('operations')),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.operations_invalid',
          ),
        ),
      );
      expect(
        () => PluginManifest.fromJson(
          _validManifest()..['operations'] = <Object?>[],
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.operations_empty',
          ),
        ),
      );
      final json = _validManifest();
      final operations = json['operations']! as List<Object?>;
      operations.add(
        Map<String, Object?>.from(operations.single as Map<String, Object?>),
      );
      expect(
        () => PluginManifest.fromJson(json),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.operation_duplicate',
          ),
        ),
      );
    });

    test('menolak operation dengan kategori, I/O, atau params invalid', () {
      Map<String, Object?> withOperation(Map<String, Object?> operation) {
        return _validManifest()..['operations'] = <Object?>[operation];
      }

      expect(
        () => PluginManifest.fromJson(
          withOperation(<String, Object?>{
            'id': 'contoh.op',
            'name': 'Op',
            'category': 'Unknown',
            'inputType': 'text',
            'outputType': 'text',
          }),
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'operation.category_invalid',
          ),
        ),
      );
      expect(
        () => PluginManifest.fromJson(
          withOperation(<String, Object?>{
            'id': 'contoh.op',
            'name': 'Op',
            'category': 'Utility',
            'inputType': 'unknown',
            'outputType': 'text',
          }),
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'operation.io_invalid',
          ),
        ),
      );
      expect(
        () => PluginManifest.fromJson(
          withOperation(<String, Object?>{
            'id': 'contoh.op',
            'name': 'Op',
            'category': 'Utility',
            'params': <Object?>[
              <String, Object?>{'key': 'x', 'label': 'X', 'type': 'boolean'},
              <String, Object?>{'key': 'x', 'label': 'X2', 'type': 'string'},
            ],
            'inputType': 'text',
            'outputType': 'text',
          }),
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.operation_params_invalid',
          ),
        ),
      );
    });

    test('menolak integrity hash invalid', () {
      expect(
        () => PluginManifest.fromJson(
          _validManifest()..['integrity'] = <String, Object?>{'sha256': 'abc'},
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.hash_invalid',
          ),
        ),
      );
    });

    test('menolak JSON invalid dan root bukan objek', () {
      expect(
        () => PluginManifest.fromJsonString('{'),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.manifest_json_invalid',
          ),
        ),
      );
      expect(
        () => PluginManifest.fromJsonString('[]'),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'plugin.manifest_invalid',
          ),
        ),
      );
    });
  });
}
