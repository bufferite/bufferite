import 'dart:async';
import 'dart:io';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/engine/pipeline.dart';
import 'package:bufferite/core/engine/pipeline_isolate.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/operations/core_operations.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

OperationRegistry _registry() {
  final registry = OperationRegistry();
  for (final operation in coreOperationsById.values) {
    registry.registerOperation(
      operation,
      pluginId: 'dev.bufferite.core',
      pluginVersion: '1.0.0',
      tier: RuntimeTier.dsl,
    );
  }
  return registry;
}

PipelineStep _step(String id, {Map<String, Object?> args = const {}}) {
  return PipelineStep(id: id, operationId: id, args: args);
}

IsolatePipelineExecutor _executor({int memoryLimitBytes = 64 * 1024 * 1024}) =>
    IsolatePipelineExecutor(
      registry: _registry(),
      stepTimeout: const Duration(seconds: 5),
      memoryLimitBytes: memoryLimitBytes,
    );

void main() {
  test('menjalankan operasi core di isolate', () async {
    final events = <PipelineEvent>[];
    final result = await _executor().execute(
      steps: <PipelineStep>[
        _step('core.base64_encode'),
        _step('core.upper_case'),
      ],
      input: const TextBuffer('1'),
      onEvent: events.add,
    );

    expect(result.output.asText(), 'MQ==');
    expect(result.errors, isEmpty);
    expect(
      events.map((event) => event.type),
      containsAllInOrder(<PipelineEventType>[
        PipelineEventType.stepStarted,
        PipelineEventType.stepSucceeded,
        PipelineEventType.stepStarted,
        PipelineEventType.stepSucceeded,
        PipelineEventType.completed,
      ]),
    );
  });

  test('data unicode dan args kompleks terkirim utuh', () async {
    const input = 'baris1\nbaris2 ✓ 你好\n';
    final result = await _executor().execute(
      steps: <PipelineStep>[
        _step('core.base64_encode'),
        _step('core.base64_decode'),
      ],
      input: const TextBuffer(input),
    );

    expect(result.output.asText(), input);
  });

  test('FileBuffer dibaca di isolate kerja', () async {
    final temp = await Directory.systemTemp.createTemp('bufferite_isolate_');
    addTearDown(() async {
      if (temp.existsSync()) {
        await temp.delete(recursive: true);
      }
    });
    final file = File('${temp.path}/input.txt');
    await file.writeAsString('halo');

    final result = await _executor().execute(
      steps: <PipelineStep>[_step('core.upper_case')],
      input: FileBuffer(path: file.path, name: 'input.txt', size: 4),
    );

    expect(result.errors, isEmpty);
    expect(result.output.asText(), 'HALO');
  });

  test('FileBuffer melebihi batas memori ditolak tanpa alokasi', () async {
    final temp = await Directory.systemTemp.createTemp('bufferite_isolate_');
    addTearDown(() async {
      if (temp.existsSync()) {
        await temp.delete(recursive: true);
      }
    });
    final file = File('${temp.path}/besar.bin');
    await file.writeAsBytes(List<int>.filled(32, 1));

    await expectLater(
      _executor(memoryLimitBytes: 16).execute(
        steps: <PipelineStep>[_step('core.upper_case')],
        input: FileBuffer(path: file.path, name: 'besar.bin', size: 32),
      ),
      throwsA(
        isA<AppError>()
            .having((error) => error.code, 'code', 'runtime.file_too_large')
            .having((error) => error.details['limit'], 'limit', 16),
      ),
    );
  });

  test('output melebihi batas memori dilaporkan sebagai error step', () async {
    final result = await _executor(memoryLimitBytes: 10).execute(
      steps: <PipelineStep>[_step('core.base64_encode')],
      input: const TextBuffer('abcdefghij'),
    );

    expect(result.isSuccess, isFalse);
    expect(result.errors, hasLength(1));
    expect(result.errors.first.code, 'runtime.memory_limit');
    expect(result.errors.first.details['limit'], 10);
  });

  test('pipeline berat tidak memblokir isolate utama', () async {
    final input = TextBuffer('a' * (8 * 1024 * 1024));
    var ticks = 0;
    final ticker = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => ticks++,
    );
    try {
      final result = await _executor().execute(
        steps: <PipelineStep>[_step('core.base64_encode')],
        input: input,
      );
      expect(result.output.asText(), hasLength(greaterThan(input.length)));
    } finally {
      ticker.cancel();
    }
    expect(ticks, greaterThan(0));
  });

  test('pembatalan menghentikan pipeline', () async {
    final token = CancellationToken()..cancel();
    final result = await _executor().execute(
      steps: <PipelineStep>[
        _step('core.base64_encode'),
        _step('core.upper_case'),
      ],
      input: TextBuffer('a' * (4 * 1024 * 1024)),
      cancellation: token,
    );

    expect(result.cancelled, isTrue);
    expect(result.isSuccess, isFalse);
  });

  test('operasi tanpa executor memakai jalur in-process', () async {
    final result = await _executor().execute(
      steps: <PipelineStep>[_step('com.example.unknown')],
      input: const TextBuffer('x'),
    );

    expect(result.output.asText(), 'x');
    expect(result.warnings, hasLength(1));
    expect(result.cancelled, isFalse);
  });
}
