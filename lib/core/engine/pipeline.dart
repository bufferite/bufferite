import 'dart:async';

import '../error/app_error.dart';
import 'buffer.dart';

/// Spesifikasi step yang tidak bergantung pada model Recipe di layer feature.
final class PipelineStep {
  PipelineStep({
    required this.id,
    required this.operationId,
    Map<String, Object?> args = const <String, Object?>{},
    this.enabled = true,
  }) : args = Map<String, Object?>.unmodifiable(args);

  final String id;
  final String operationId;
  final Map<String, Object?> args;
  final bool enabled;

  factory PipelineStep.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final operationId = json['operationId'];
    if (id is! String || operationId is! String) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'pipeline.step_invalid',
        message: 'Step membutuhkan id dan operationId bertipe string.',
      );
    }
    final args = json['args'] ?? const <String, Object?>{};
    if (args is! Map<String, Object?>) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'pipeline.step_invalid',
        message: 'Args step harus berupa objek.',
      );
    }
    final enabled = json['enabled'] ?? true;
    if (enabled is! bool) {
      throw const AppError(
        category: ErrorCategory.validation,
        code: 'pipeline.step_invalid',
        message: 'Field enabled harus berupa boolean.',
      );
    }
    return PipelineStep(
      id: id,
      operationId: operationId,
      args: args,
      enabled: enabled,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'operationId': operationId,
      'args': args,
      'enabled': enabled,
    };
  }
}

enum PipelineErrorPolicy {
  /// Hentikan pipeline pada error pertama (default MVP, menunggu D06).
  stop,

  /// Lanjutkan step berikutnya dengan output valid terakhir.
  continueWithLastOutput,
}

enum PipelineEventType {
  stepStarted,
  stepSucceeded,
  stepSkipped,
  stepFailed,
  completed,
  cancelled,
}

final class PipelineEvent {
  const PipelineEvent({
    required this.type,
    required this.stepIndex,
    this.stepId,
    this.operationId,
    this.output,
    this.error,
    this.message,
  });

  final PipelineEventType type;

  /// Indeks step; untuk event completed/cancelled sama dengan jumlah step
  /// yang sudah diproses.
  final int stepIndex;
  final String? stepId;
  final String? operationId;
  final Buffer? output;
  final AppError? error;
  final String? message;

  @override
  String toString() {
    return 'PipelineEvent(${type.name}, stepIndex: $stepIndex, '
        'stepId: $stepId, error: ${error?.code})';
  }
}

final class PipelineResult {
  PipelineResult({
    required this.output,
    required List<PipelineEvent> events,
    required List<AppError> errors,
    required List<AppError> warnings,
    required this.cancelled,
  }) : events = List<PipelineEvent>.unmodifiable(events),
       errors = List<AppError>.unmodifiable(errors),
       warnings = List<AppError>.unmodifiable(warnings);

  /// Output valid terakhir. Jika tidak ada step berhasil, sama dengan input.
  final Buffer output;
  final List<PipelineEvent> events;
  final List<AppError> errors;

  /// Peringatan non-fatal, mis. step unsupported yang dilewati.
  final List<AppError> warnings;
  final bool cancelled;

  bool get isSuccess => errors.isEmpty && !cancelled;
}

/// Token pembatalan best-effort untuk eksekusi pipeline.
///
/// Operasi yang sedang berjalan tidak dapat dihentikan paksa oleh Dart;
/// runtime plugin wajib memeriksa token/isolate kill saat implementasinya
/// tersedia (F05).
final class CancellationToken {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}
