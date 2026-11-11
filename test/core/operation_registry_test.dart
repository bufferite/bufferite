import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_param.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_operations.dart';

void main() {
  group('OperationRegistry', () {
    test('mendaftarkan dan mencari operasi', () {
      final registry = OperationRegistry();
      final result = registry.registerOperation(
        const ReverseTextOperation(),
        pluginId: 'com.test.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.dsl,
      );

      expect(result.isSuccess, isTrue);
      expect(registry.count, 1);
      expect(registry.byId('test.reverse')?.executor, isNotNull);
      expect(registry.all().single.descriptor.id, 'test.reverse');
      expect(registry.search('reverse').single.descriptor.id, 'test.reverse');
      expect(
        registry.byCategory(OperationCategory.utility).single.descriptor.id,
        'test.reverse',
      );
      expect(registry.byPlugin('com.test.pack').length, 1);
    });

    test('menolak ID duplikat dan mempertahankan yang pertama', () {
      final registry = OperationRegistry();
      registry.registerOperation(
        const ReverseTextOperation(),
        pluginId: 'first.plugin',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.dsl,
      );
      final duplicate = registry.registerOperation(
        const ReverseTextOperation(),
        pluginId: 'second.plugin',
        pluginVersion: '2.0.0',
        tier: RuntimeTier.lua,
      );

      expect(duplicate.errorOrNull?.code, 'operation.duplicate_id');
      expect(registry.count, 1);
      expect(
        registry.byId('test.reverse')?.descriptor.pluginId,
        'first.plugin',
      );
      expect(registry.warnings, hasLength(1));
    });

    test('menyembunyikan operasi dengan kontrak tidak didukung', () {
      final registry = OperationRegistry();
      registry.registerOperation(
        const ReverseTextOperation(),
        pluginId: 'future.plugin',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.wasm,
        contractVersion: operationContractVersion + 1,
      );

      expect(registry.all(), isEmpty);
      expect(registry.all(includeUnsupported: true), hasLength(1));
      expect(
        registry.require('test.reverse').errorOrNull?.code,
        'operation.unsupported',
      );
    });

    test('menghormati status available plugin', () {
      final registry = OperationRegistry();
      registry.registerOperation(
        const ReverseTextOperation(),
        pluginId: 'com.test.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.dsl,
        available: false,
      );

      expect(registry.all(), isEmpty);
      expect(
        registry.require('test.reverse').errorOrNull?.code,
        'operation.unsupported',
      );

      expect(
        registry.setPluginAvailability('com.test.pack', available: true),
        1,
      );
      expect(registry.require('test.reverse').isSuccess, isTrue);
    });

    test('menolak eksekusi tanpa executor', () {
      final registry = OperationRegistry();
      registry.register(
        OperationDescriptor(
          id: 'test.manifest_only',
          name: 'Manifest Only',
          category: OperationCategory.utility,
          pluginId: 'com.test.pack',
          pluginVersion: '1.0.0',
          tier: RuntimeTier.lua,
          params: const <OperationParam>[],
          io: const OperationIO(
            input: BufferKind.text,
            output: BufferKind.text,
          ),
        ),
      );

      final result = registry.require('test.manifest_only');
      expect(result.errorOrNull?.code, 'operation.unsupported');
      expect(result.errorOrNull?.pluginId, 'com.test.pack');
    });

    test('menghapus operasi berdasarkan plugin', () {
      final registry = OperationRegistry();
      registry.registerOperation(
        const ReverseTextOperation(),
        pluginId: 'com.test.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.dsl,
      );

      expect(registry.unregisterByPlugin('com.test.pack'), 1);
      expect(registry.count, 0);
      expect(registry.unregister('test.reverse'), isFalse);
    });
  });

  group('OperationDescriptor', () {
    test('fromOperation menyalin metadata operasi', () {
      const operation = ReverseTextOperation();
      final descriptor = OperationDescriptor.fromOperation(
        operation,
        pluginId: 'com.test.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.lua,
      );

      expect(descriptor.id, operation.id);
      expect(descriptor.name, operation.name);
      expect(descriptor.category, operation.category);
      expect(descriptor.params, operation.params);
      expect(descriptor.io, operation.io);
      expect(descriptor.tier, RuntimeTier.lua);
      expect(descriptor.isSupported, isTrue);
      expect(descriptor.isContractSupported, isTrue);
    });

    test('copyWith hanya mengubah availability', () {
      final descriptor = OperationDescriptor(
        id: 'test.op',
        name: 'Op',
        category: OperationCategory.utility,
        pluginId: 'com.test.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.dsl,
        params: const <OperationParam>[],
        io: const OperationIO(input: BufferKind.text, output: BufferKind.text),
      );

      final disabled = descriptor.copyWith(available: false);

      expect(disabled.available, isFalse);
      expect(disabled.id, descriptor.id);
      expect(descriptor.available, isTrue);
      expect(
        () => descriptor.params.add(
          const OperationParam(
            key: 'x',
            label: 'X',
            type: OperationParamType.string,
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('Metadata operasi', () {
    test('parse kategori dan tier', () {
      expect(
        OperationCategory.parse('Encode/Decode'),
        OperationCategory.encodeDecode,
      );
      expect(
        OperationCategory.parse('encodedecode'),
        OperationCategory.encodeDecode,
      );
      expect(RuntimeTier.parse('lua'), RuntimeTier.lua);
      expect(() => OperationCategory.parse('nope'), throwsA(isA<AppError>()));
      expect(() => RuntimeTier.parse('native'), throwsA(isA<AppError>()));
    });

    test('OperationIO JSON round-trip', () {
      const io = OperationIO(input: BufferKind.text, output: BufferKind.bytes);

      expect(OperationIO.fromJson(io.toJson()).toJson(), io.toJson());
      expect(
        () => OperationIO.fromJson(<String, Object?>{
          'input': 'text',
          'output': 'nope',
        }),
        throwsA(isA<AppError>()),
      );
    });
  });
}
