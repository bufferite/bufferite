import 'dart:async';

import '../error/app_error.dart';
import '../plugin/operation_param.dart';
import '../plugin/operation_registry.dart';
import 'buffer.dart';
import 'pipeline.dart';

/// Menjalankan step recipe secara sekuensial dengan dispatch ke
/// [OperationRegistry].
///
/// Eksekusi berjalan pada isolate pemanggil. Pembungkusan ke isolate kerja
/// dilakukan oleh layer runtime (lihat blocker F03-T04 di `progress.md`);
/// executor ini tidak boleh memblokir UI dan menerima pembatalan best-effort.
final class PipelineExecutor {
  PipelineExecutor({
    required this.registry,
    this.stepTimeout = const Duration(seconds: 2),
    this.errorPolicy = PipelineErrorPolicy.stop,
    this.memoryLimitBytes,
  }) {
    if (stepTimeout <= Duration.zero) {
      throw ArgumentError.value(
        stepTimeout,
        'stepTimeout',
        'Harus lebih dari nol.',
      );
    }
    if (memoryLimitBytes != null && memoryLimitBytes! <= 0) {
      throw ArgumentError.value(
        memoryLimitBytes,
        'memoryLimitBytes',
        'Harus lebih dari nol.',
      );
    }
  }

  final OperationRegistry registry;
  final Duration stepTimeout;
  final PipelineErrorPolicy errorPolicy;

  /// Batas ukuran output per step. `null` berarti tanpa batas eksplisit.
  final int? memoryLimitBytes;

  Future<PipelineResult> execute({
    required List<PipelineStep> steps,
    required Buffer input,
    void Function(PipelineEvent event)? onEvent,
    CancellationToken? cancellation,
  }) async {
    final events = <PipelineEvent>[];
    final errors = <AppError>[];
    final warnings = <AppError>[];
    var current = input;

    void emit(PipelineEvent event) {
      events.add(event);
      onEvent?.call(event);
    }

    PipelineResult buildResult({bool cancelled = false}) {
      return PipelineResult(
        output: current,
        events: events,
        errors: errors,
        warnings: warnings,
        cancelled: cancelled,
      );
    }

    for (var index = 0; index < steps.length; index++) {
      if (cancellation?.isCancelled ?? false) {
        emit(
          PipelineEvent(
            type: PipelineEventType.cancelled,
            stepIndex: index,
            message: 'Eksekusi dibatalkan.',
          ),
        );
        return buildResult(cancelled: true);
      }

      final step = steps[index];
      if (!step.enabled) {
        emit(
          PipelineEvent(
            type: PipelineEventType.stepSkipped,
            stepIndex: index,
            stepId: step.id,
            operationId: step.operationId,
            message: 'Step dinonaktifkan.',
          ),
        );
        continue;
      }

      final resolved = registry.require(step.operationId);
      if (!resolved.isSuccess) {
        final warning = resolved.errorOrNull!.copyWith(stepId: step.id);
        warnings.add(warning);
        emit(
          PipelineEvent(
            type: PipelineEventType.stepSkipped,
            stepIndex: index,
            stepId: step.id,
            operationId: step.operationId,
            error: warning,
            message: warning.message,
          ),
        );
        continue;
      }

      final entry = resolved.valueOrNull!;
      final resolvedArgs = resolveOperationArgs(
        entry.descriptor.params,
        step.args,
      );
      if (!resolvedArgs.isSuccess) {
        final error = resolvedArgs.errorOrNull!.copyWith(
          stepId: step.id,
          pluginId: entry.descriptor.pluginId,
        );
        errors.add(error);
        emit(
          PipelineEvent(
            type: PipelineEventType.stepFailed,
            stepIndex: index,
            stepId: step.id,
            operationId: step.operationId,
            error: error,
          ),
        );
        if (errorPolicy == PipelineErrorPolicy.stop) {
          return buildResult();
        }
        continue;
      }

      emit(
        PipelineEvent(
          type: PipelineEventType.stepStarted,
          stepIndex: index,
          stepId: step.id,
          operationId: step.operationId,
        ),
      );

      try {
        final output = await _runOperation(
          entry,
          current,
          resolvedArgs.valueOrNull ?? const <String, Object?>{},
          cancellation,
        );
        _ensureWithinMemory(output);
        current = output;
        emit(
          PipelineEvent(
            type: PipelineEventType.stepSucceeded,
            stepIndex: index,
            stepId: step.id,
            operationId: step.operationId,
            output: output,
          ),
        );
      } on AppError catch (error) {
        if (error.category == ErrorCategory.cancelled) {
          emit(
            PipelineEvent(
              type: PipelineEventType.cancelled,
              stepIndex: index,
              stepId: step.id,
              operationId: step.operationId,
              message: error.message,
            ),
          );
          return buildResult(cancelled: true);
        }

        final wrapped = error.copyWith(
          stepId: step.id,
          pluginId: error.pluginId ?? entry.descriptor.pluginId,
        );
        errors.add(wrapped);
        emit(
          PipelineEvent(
            type: PipelineEventType.stepFailed,
            stepIndex: index,
            stepId: step.id,
            operationId: step.operationId,
            error: wrapped,
          ),
        );
        if (errorPolicy == PipelineErrorPolicy.stop) {
          return buildResult();
        }
      } on Object catch (error) {
        final wrapped = AppError(
          category: ErrorCategory.runtime,
          code: 'runtime.trap',
          message: 'Operasi ${step.operationId} gagal: $error',
          pluginId: entry.descriptor.pluginId,
          stepId: step.id,
          details: <String, Object?>{'error': error.toString()},
        );
        errors.add(wrapped);
        emit(
          PipelineEvent(
            type: PipelineEventType.stepFailed,
            stepIndex: index,
            stepId: step.id,
            operationId: step.operationId,
            error: wrapped,
          ),
        );
        if (errorPolicy == PipelineErrorPolicy.stop) {
          return buildResult();
        }
      }
    }

    if (cancellation?.isCancelled ?? false) {
      emit(
        PipelineEvent(
          type: PipelineEventType.cancelled,
          stepIndex: steps.length,
          message: 'Eksekusi dibatalkan.',
        ),
      );
      return buildResult(cancelled: true);
    }

    emit(
      PipelineEvent(
        type: PipelineEventType.completed,
        stepIndex: steps.length,
        output: current,
      ),
    );
    return buildResult();
  }

  /// Varian stream untuk UI yang ingin berlangganan progres live.
  Stream<PipelineEvent> stream({
    required List<PipelineStep> steps,
    required Buffer input,
    CancellationToken? cancellation,
  }) {
    final controller = StreamController<PipelineEvent>();
    unawaited(() async {
      try {
        await execute(
          steps: steps,
          input: input,
          onEvent: controller.add,
          cancellation: cancellation,
        );
      } on Object catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      } finally {
        await controller.close();
      }
    }());

    return controller.stream;
  }

  void _ensureWithinMemory(Buffer buffer) {
    final limit = memoryLimitBytes;
    if (limit == null) {
      return;
    }
    final size = buffer is TextBuffer && buffer.encoding.name == 'utf-8'
        ? _utf8Length(buffer.value)
        : buffer.length;
    if (size > limit) {
      throw AppError(
        category: ErrorCategory.runtime,
        code: 'runtime.memory_limit',
        message:
            'Output berukuran $size byte melebihi batas memori $limit byte.',
        details: <String, Object?>{'size': size, 'limit': limit},
      );
    }
  }

  Future<Buffer> _runOperation(
    RegisteredOperation entry,
    Buffer input,
    Map<String, Object?> args,
    CancellationToken? cancellation,
  ) {
    if (cancellation?.isCancelled ?? false) {
      return Future<Buffer>.error(
        const AppError(
          category: ErrorCategory.cancelled,
          code: 'operation.cancelled',
          message: 'Eksekusi dibatalkan.',
        ),
      );
    }

    final executor = entry.executor;
    if (executor == null) {
      return Future<Buffer>.error(
        AppError(
          category: ErrorCategory.unsupported,
          code: 'operation.unsupported',
          message: 'Runtime operasi ${entry.descriptor.id} belum siap.',
          pluginId: entry.descriptor.pluginId,
        ),
      );
    }

    final operation = Future<Buffer>.sync(() => executor.execute(input, args));
    final withTimeout = operation.timeout(
      stepTimeout,
      onTimeout: () {
        throw AppError(
          category: ErrorCategory.runtime,
          code: 'runtime.timeout',
          message:
              'Operasi ${entry.descriptor.id} melewati batas waktu '
              '${stepTimeout.inMilliseconds} ms.',
          pluginId: entry.descriptor.pluginId,
          details: <String, Object?>{'timeoutMs': stepTimeout.inMilliseconds},
        );
      },
    );

    if (cancellation == null) {
      return withTimeout;
    }

    final cancelled = cancellation.whenCancelled.then<Buffer>((_) {
      throw const AppError(
        category: ErrorCategory.cancelled,
        code: 'operation.cancelled',
        message: 'Eksekusi dibatalkan.',
      );
    });

    return Future.any<Buffer>(<Future<Buffer>>[withTimeout, cancelled]);
  }
}

/// Panjang UTF-8 tanpa membuat salinan byte, untuk cek batas memori.
int _utf8Length(String value) {
  var bytes = 0;
  for (final rune in value.runes) {
    if (rune <= 0x7F) {
      bytes += 1;
    } else if (rune <= 0x7FF) {
      bytes += 2;
    } else if (rune <= 0xFFFF) {
      bytes += 3;
    } else {
      bytes += 4;
    }
  }
  return bytes;
}
