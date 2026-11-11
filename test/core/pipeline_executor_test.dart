import 'dart:convert';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/engine/pipeline.dart';
import 'package:bufferite/core/engine/pipeline_executor.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_operations.dart';
import 'support/pipeline_operations.dart';

PipelineStep _step(
  String id,
  String operationId, {
  Map<String, Object?> args = const <String, Object?>{},
  bool enabled = true,
}) {
  return PipelineStep(
    id: id,
    operationId: operationId,
    args: args,
    enabled: enabled,
  );
}

OperationRegistry _baseRegistry() {
  final registry = OperationRegistry();
  registry.registerOperation(
    const Base64DecodeOperation(),
    pluginId: 'core.test',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.lua,
  );
  registry.registerOperation(
    const ReverseTextOperation(),
    pluginId: 'com.test.pack',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  return registry;
}

void main() {
  group('PipelineExecutor eksekusi', () {
    test('menjalankan step sekuensial dan mengirim output live', () async {
      final executor = PipelineExecutor(registry: _baseRegistry());
      final live = <PipelineEvent>[];

      final result = await executor.execute(
        steps: <PipelineStep>[
          _step('step-1', 'test.base64_decode'),
          _step('step-2', 'test.reverse'),
        ],
        input: const TextBuffer('SGVsbG8='),
        onEvent: live.add,
      );

      expect(result.isSuccess, isTrue);
      expect(result.output, const TextBuffer('olleH'));
      expect(result.events, hasLength(5));
      expect(result.events.first.type, PipelineEventType.stepStarted);
      expect(result.events.last.type, PipelineEventType.completed);
      expect(result.events[1].output, BytesBuffer(utf8.encode('Hello')));
      expect(result.events[3].output, const TextBuffer('olleH'));
      expect(live, hasLength(result.events.length));
    });

    test('melewati step disabled tanpa memanggil operasi', () async {
      final registry = _baseRegistry();
      final counting = CountingOperation(id: 'test.count', name: 'Counting');
      registry.registerOperation(
        counting,
        pluginId: 'com.test.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.dsl,
      );
      final executor = PipelineExecutor(registry: registry);

      final result = await executor.execute(
        steps: <PipelineStep>[_step('step-1', 'test.count', enabled: false)],
        input: const TextBuffer('halo'),
      );

      expect(result.isSuccess, isTrue);
      expect(counting.calls, 0);
      expect(result.output, const TextBuffer('halo'));
      expect(result.events.first.type, PipelineEventType.stepSkipped);
      expect(result.events.first.message, contains('dinonaktifkan'));
      expect(result.events.last.type, PipelineEventType.completed);
    });

    test('melewati operasi tidak dikenal dengan peringatan', () async {
      final executor = PipelineExecutor(registry: _baseRegistry());

      final result = await executor.execute(
        steps: <PipelineStep>[
          _step('step-1', 'tidak.ada'),
          _step('step-2', 'test.reverse'),
        ],
        input: const TextBuffer('abc'),
      );

      expect(result.isSuccess, isTrue);
      expect(result.output, const TextBuffer('cba'));
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.code, 'operation.not_found');
      expect(result.warnings.single.stepId, 'step-1');
      expect(result.events[0].type, PipelineEventType.stepSkipped);
      expect(result.events[0].error, isNotNull);
    });

    test('melewati operasi unsupported dengan peringatan', () async {
      final registry = _baseRegistry();
      registry.setPluginAvailability('com.test.pack', available: false);
      final executor = PipelineExecutor(registry: registry);

      final result = await executor.execute(
        steps: <PipelineStep>[_step('step-1', 'test.reverse')],
        input: const TextBuffer('abc'),
      );

      expect(result.isSuccess, isTrue);
      expect(result.warnings.single.code, 'operation.unsupported');
      expect(result.output, const TextBuffer('abc'));
    });

    test('menghentikan pipeline pada args tidak valid', () async {
      final executor = PipelineExecutor(registry: _baseRegistry());

      final result = await executor.execute(
        steps: <PipelineStep>[
          _step(
            'step-1',
            'test.reverse',
            args: <String, Object?>{'unknown': true},
          ),
          _step('step-2', 'test.reverse'),
        ],
        input: const TextBuffer('abc'),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errors.single.code, 'operation.param_unknown');
      expect(result.errors.single.stepId, 'step-1');
      expect(result.errors.single.pluginId, 'com.test.pack');
      expect(result.output, const TextBuffer('abc'));
      expect(result.events.last.type, PipelineEventType.stepFailed);
    });

    test(
      'error di tengah pipeline mengembalikan output valid terakhir',
      () async {
        final registry = _baseRegistry();
        final counting = CountingOperation(id: 'test.count', name: 'Counting');
        registry.registerOperation(
          const FailingOperation(
            error: AppError(
              category: ErrorCategory.validation,
              code: 'operation.invalid_input',
              message: 'Input salah.',
            ),
          ),
          pluginId: 'com.fail.pack',
          pluginVersion: '1.0.0',
          tier: RuntimeTier.lua,
        );
        registry.registerOperation(
          counting,
          pluginId: 'com.test.pack',
          pluginVersion: '1.0.0',
          tier: RuntimeTier.dsl,
        );
        final executor = PipelineExecutor(registry: registry);

        final result = await executor.execute(
          steps: <PipelineStep>[
            _step('step-1', 'test.base64_decode'),
            _step('step-2', 'test.fail'),
            _step('step-3', 'test.count'),
          ],
          input: const TextBuffer('SGVsbG8='),
        );

        expect(result.isSuccess, isFalse);
        expect(result.errors.single.stepId, 'step-2');
        expect(result.output, BytesBuffer(utf8.encode('Hello')));
        expect(counting.calls, 0);
        expect(result.events.last.type, PipelineEventType.stepFailed);
      },
    );

    test('policy continue melanjutkan dengan output terakhir', () async {
      final executor = PipelineExecutor(
        registry: _baseRegistry(),
        errorPolicy: PipelineErrorPolicy.continueWithLastOutput,
      );

      final result = await executor.execute(
        steps: <PipelineStep>[
          _step(
            'step-1',
            'test.reverse',
            args: <String, Object?>{'unknown': true},
          ),
          _step('step-2', 'test.reverse'),
        ],
        input: const TextBuffer('abc'),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errors, hasLength(1));
      expect(result.output, const TextBuffer('cba'));
      expect(result.events.last.type, PipelineEventType.completed);
    });

    test('membungkus AppError operasi dengan plugin dan step', () async {
      final registry = _baseRegistry();
      registry.registerOperation(
        const FailingOperation(
          error: AppError(
            category: ErrorCategory.validation,
            code: 'operation.invalid_input',
            message: 'Input salah.',
          ),
        ),
        pluginId: 'com.fail.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.lua,
      );
      final executor = PipelineExecutor(registry: registry);

      final result = await executor.execute(
        steps: <PipelineStep>[_step('step-1', 'test.fail')],
        input: const TextBuffer('abc'),
      );

      expect(result.errors.single.code, 'operation.invalid_input');
      expect(result.errors.single.pluginId, 'com.fail.pack');
      expect(result.errors.single.stepId, 'step-1');
      expect(result.output, const TextBuffer('abc'));
    });

    test('membungkus exception tak terduga sebagai runtime.trap', () async {
      final registry = _baseRegistry();
      registry.registerOperation(
        const ExplodingOperation(),
        pluginId: 'com.fail.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.wasm,
      );
      final executor = PipelineExecutor(registry: registry);

      final result = await executor.execute(
        steps: <PipelineStep>[_step('step-1', 'test.explode')],
        input: const TextBuffer('abc'),
      );

      expect(result.errors.single.code, 'runtime.trap');
      expect(result.errors.single.pluginId, 'com.fail.pack');
      expect(result.errors.single.details['error'], contains('boom'));
    });

    test('menghentikan operasi yang melewati batas waktu', () async {
      final registry = _baseRegistry();
      registry.registerOperation(
        const SlowOperation(delay: Duration(milliseconds: 50)),
        pluginId: 'com.slow.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.lua,
      );
      final executor = PipelineExecutor(
        registry: registry,
        stepTimeout: const Duration(milliseconds: 5),
      );

      final result = await executor.execute(
        steps: <PipelineStep>[_step('step-1', 'test.slow')],
        input: const TextBuffer('abc'),
      );

      expect(result.errors.single.code, 'runtime.timeout');
      expect(result.errors.single.stepId, 'step-1');
      expect(result.errors.single.details['timeoutMs'], 5);
    });

    test('tidak memutasi input dan menangani pipeline kosong', () async {
      final input = BytesBuffer(<int>[1, 2, 3]);
      final before = input.asBytes();
      final executor = PipelineExecutor(registry: _baseRegistry());

      final result = await executor.execute(
        steps: const <PipelineStep>[],
        input: input,
      );

      expect(result.isSuccess, isTrue);
      expect(result.output, input);
      expect(result.events.single.type, PipelineEventType.completed);
      expect(input.asBytes(), before);
    });
  });

  group('PipelineExecutor pembatalan', () {
    test('membatalkan sebelum step pertama dimulai', () async {
      final executor = PipelineExecutor(registry: _baseRegistry());
      final token = CancellationToken()..cancel();

      final result = await executor.execute(
        steps: <PipelineStep>[_step('step-1', 'test.reverse')],
        input: const TextBuffer('abc'),
        cancellation: token,
      );

      expect(result.cancelled, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.output, const TextBuffer('abc'));
      expect(result.events.single.type, PipelineEventType.cancelled);
    });

    test('membatalkan operasi yang sedang berjalan', () async {
      final registry = _baseRegistry();
      registry.registerOperation(
        const SlowOperation(delay: Duration(milliseconds: 100)),
        pluginId: 'com.slow.pack',
        pluginVersion: '1.0.0',
        tier: RuntimeTier.lua,
      );
      final executor = PipelineExecutor(registry: registry);
      final token = CancellationToken();

      final future = executor.execute(
        steps: <PipelineStep>[_step('step-1', 'test.slow')],
        input: const TextBuffer('abc'),
        cancellation: token,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      token.cancel();
      final result = await future;

      expect(result.cancelled, isTrue);
      expect(result.errors, isEmpty);
      expect(
        result.events.any((event) => event.type == PipelineEventType.cancelled),
        isTrue,
      );
    });
  });

  group('PipelineExecutor stream', () {
    test('mengirim event hingga completed', () async {
      final executor = PipelineExecutor(registry: _baseRegistry());

      final events = await executor
          .stream(
            steps: <PipelineStep>[
              _step('step-1', 'test.base64_decode'),
              _step('step-2', 'test.reverse'),
            ],
            input: const TextBuffer('SGVsbG8='),
          )
          .toList();

      expect(events.last.type, PipelineEventType.completed);
      expect(events.last.output, const TextBuffer('olleH'));
      expect(
        events.where((event) => event.type == PipelineEventType.stepStarted),
        hasLength(2),
      );
    });
  });
}
