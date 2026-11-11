import 'dart:io';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/engine/pipeline.dart';
import 'package:bufferite/core/engine/pipeline_executor.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_param.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';

final class _NoopOperation implements Operation {
  const _NoopOperation();

  @override
  String get id => 'bench.noop';

  @override
  String get name => 'No-op';

  @override
  OperationCategory get category => OperationCategory.utility;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io =>
      const OperationIO(input: BufferKind.text, output: BufferKind.text);

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    return input;
  }
}

Future<void> main() async {
  const stepCount = 10000;
  final registry = OperationRegistry();
  registry.registerOperation(
    const _NoopOperation(),
    pluginId: 'bench',
    pluginVersion: '1.0.0',
    tier: RuntimeTier.dsl,
  );
  final steps = List<PipelineStep>.generate(
    stepCount,
    (index) => PipelineStep(id: 'step-$index', operationId: 'bench.noop'),
  );
  final executor = PipelineExecutor(registry: registry);

  await executor.execute(
    steps: steps.take(100).toList(),
    input: const TextBuffer('warmup'),
  );

  final stopwatch = Stopwatch()..start();
  final result = await executor.execute(
    steps: steps,
    input: const TextBuffer('hello'),
  );
  stopwatch.stop();

  final elapsedMs = stopwatch.elapsedMilliseconds;
  final stepsPerSecond = elapsedMs == 0
      ? double.infinity
      : stepCount * 1000 / elapsedMs;
  stdout.writeln(
    'pipeline benchmark: steps=$stepCount '
    'elapsed=${elapsedMs}ms '
    'throughput=${stepsPerSecond.toStringAsFixed(0)} steps/s '
    'events=${result.events.length}',
  );

  if (!result.isSuccess) {
    stderr.writeln('Benchmark gagal: ${result.errors.first.code}');
    exitCode = 1;
  }
}
