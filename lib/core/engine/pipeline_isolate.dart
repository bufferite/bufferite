import 'dart:async';
import 'dart:isolate';

import '../error/app_error.dart';
import '../operations/core_operations.dart';
import '../plugin/operation.dart';
import '../plugin/operation_registry.dart';
import 'buffer.dart';
import 'pipeline.dart';
import 'pipeline_executor.dart';

/// Menjalankan pipeline operasi core di isolate kerja (F03-T04).
///
/// Operasi plugin non-core (DSL/Lua/WASM) belum punya executor Dart, jadi
/// pipeline yang memuatnya otomatis memakai [PipelineExecutor] in-process.
/// Protokol pesan: ready → run → event* → done (lihat `_pipelineIsolateMain`).
final class IsolatePipelineExecutor {
  IsolatePipelineExecutor({
    required this.registry,
    this.stepTimeout = const Duration(seconds: 2),
    this.errorPolicy = PipelineErrorPolicy.stop,
  });

  final OperationRegistry registry;
  final Duration stepTimeout;
  final PipelineErrorPolicy errorPolicy;

  PipelineExecutor get _fallback => PipelineExecutor(
    registry: registry,
    stepTimeout: stepTimeout,
    errorPolicy: errorPolicy,
  );

  bool _canIsolate(List<PipelineStep> steps, Buffer input) {
    if (input.kind == BufferKind.file) {
      return false;
    }
    return steps.every(
      (step) => coreOperationsById.containsKey(step.operationId),
    );
  }

  Future<PipelineResult> execute({
    required List<PipelineStep> steps,
    required Buffer input,
    void Function(PipelineEvent event)? onEvent,
    CancellationToken? cancellation,
  }) async {
    if (!_canIsolate(steps, input)) {
      return _fallback.execute(
        steps: steps,
        input: input,
        onEvent: onEvent,
        cancellation: cancellation,
      );
    }

    if (cancellation?.isCancelled ?? false) {
      const event = PipelineEvent(
        type: PipelineEventType.cancelled,
        stepIndex: 0,
        message: 'Eksekusi dibatalkan.',
      );
      onEvent?.call(event);
      return PipelineResult(
        output: input,
        events: const <PipelineEvent>[event],
        errors: const <AppError>[],
        warnings: const <AppError>[],
        cancelled: true,
      );
    }

    final events = <PipelineEvent>[];
    var emittedAny = false;
    final receive = ReceivePort();
    final ready = Completer<(SendPort, SendPort)>();
    final done = Completer<PipelineResult>();
    Isolate? isolate;

    void emit(PipelineEvent event) {
      emittedAny = true;
      events.add(event);
      onEvent?.call(event);
    }

    PipelineResult buildResult(Buffer output, {bool cancelled = false}) {
      return PipelineResult(
        output: output,
        events: events,
        errors: <AppError>[
          for (final event in events)
            if (event.type == PipelineEventType.stepFailed &&
                event.error != null)
              event.error!,
        ],
        warnings: <AppError>[
          for (final event in events)
            if (event.type == PipelineEventType.stepSkipped &&
                event.error != null)
              event.error!,
        ],
        cancelled: cancelled,
      );
    }

    receive.listen((message) {
      if (message is! Map<Object?, Object?>) {
        return;
      }
      switch (message['type']) {
        case 'ready':
          final out = message['port'];
          final control = message['control'];
          if (out is SendPort && control is SendPort && !ready.isCompleted) {
            ready.complete((out, control));
          }
        case 'event':
          final raw = message['event'];
          if (raw is Map<String, Object?>) {
            emit(PipelineEvent.fromJson(raw));
          }
        case 'done':
          final rawOutput = message['output'];
          final output = rawOutput is Map<String, Object?>
              ? Buffer.fromJson(rawOutput)
              : input;
          if (!done.isCompleted) {
            done.complete(
              buildResult(output, cancelled: message['cancelled'] == true),
            );
          }
        case 'fatal':
          final raw = message['error'];
          final error = raw is Map<String, Object?>
              ? AppError.fromJson(raw)
              : const AppError(
                  category: ErrorCategory.runtime,
                  code: 'runtime.isolate_failed',
                  message: 'Isolate pipeline gagal tanpa detail.',
                );
          if (!done.isCompleted) {
            done.completeError(error);
          }
      }
    });

    try {
      isolate = await Isolate.spawn(_pipelineIsolateMain, receive.sendPort);
      final ports = await ready.future.timeout(const Duration(seconds: 5));
      if (done.isCompleted) {
        return await done.future;
      }

      ports.$1.send(<String, Object?>{
        'type': 'run',
        'steps': <Map<String, Object?>>[
          for (final step in steps) step.toJson(),
        ],
        'input': input.toJson(),
        'timeoutMs': stepTimeout.inMilliseconds,
        'errorPolicy': errorPolicy.name,
      });

      unawaited(
        cancellation?.whenCancelled.then<void>((_) {
          ports.$2.send('cancel');
          Timer(const Duration(milliseconds: 250), () {
            if (done.isCompleted) {
              return;
            }
            isolate?.kill(priority: Isolate.immediate);
            emit(
              PipelineEvent(
                type: PipelineEventType.cancelled,
                stepIndex: events.length,
                message: 'Eksekusi dibatalkan.',
              ),
            );
            done.complete(buildResult(input, cancelled: true));
          });
        }),
      );

      return await done.future;
    } on Object {
      if (emittedAny || done.isCompleted) {
        rethrow;
      }
      // Fallback in-process hanya jika isolate gagal sebelum mengirim event.
      return _fallback.execute(
        steps: steps,
        input: input,
        onEvent: onEvent,
        cancellation: cancellation,
      );
    } finally {
      receive.close();
      isolate?.kill(priority: Isolate.beforeNextEvent);
    }
  }
}

/// Entry point isolate. Wajib top-level agar bisa dikirim ke [Isolate.spawn].
Future<void> _pipelineIsolateMain(SendPort mainPort) async {
  final inbox = ReceivePort();
  final control = ReceivePort();
  final token = CancellationToken();
  final controlSubscription = control.listen((message) {
    if (message == 'cancel') {
      token.cancel();
    }
  });

  try {
    mainPort.send(<String, Object?>{
      'type': 'ready',
      'port': inbox.sendPort,
      'control': control.sendPort,
    });

    final message = await inbox.first;
    if (message is! Map<Object?, Object?> || message['type'] != 'run') {
      throw const FormatException('Pesan run tidak valid.');
    }

    final rawSteps = message['steps'];
    final rawInput = message['input'];
    if (rawSteps is! List<Object?> || rawInput is! Map<String, Object?>) {
      throw const FormatException('Payload pipeline tidak valid.');
    }

    final steps = <PipelineStep>[
      for (final step in rawSteps)
        if (step is Map<String, Object?>) PipelineStep.fromJson(step),
    ];
    final input = Buffer.fromJson(rawInput);
    final timeoutMs = message['timeoutMs'];
    final policyName = message['errorPolicy'];

    final executor = PipelineExecutor(
      registry: _coreOnlyRegistry(),
      stepTimeout: Duration(
        milliseconds: timeoutMs is int && timeoutMs > 0 ? timeoutMs : 2000,
      ),
      errorPolicy: PipelineErrorPolicy.values.firstWhere(
        (policy) => policy.name == policyName,
        orElse: () => PipelineErrorPolicy.stop,
      ),
    );

    final result = await executor.execute(
      steps: steps,
      input: input,
      onEvent: (event) => mainPort.send(<String, Object?>{
        'type': 'event',
        'event': event.toJson(),
      }),
      cancellation: token,
    );

    mainPort.send(<String, Object?>{
      'type': 'done',
      'output': result.output.toJson(),
      'cancelled': result.cancelled,
    });
  } on Object catch (error) {
    mainPort.send(<String, Object?>{
      'type': 'fatal',
      'error': AppError(
        category: ErrorCategory.runtime,
        code: 'runtime.isolate_failed',
        message: 'Pipeline isolate gagal: $error',
        details: <String, Object?>{'error': error.toString()},
      ).toJson(),
    });
  } finally {
    await controlSubscription.cancel();
    inbox.close();
    control.close();
  }
}

OperationRegistry _coreOnlyRegistry() {
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
