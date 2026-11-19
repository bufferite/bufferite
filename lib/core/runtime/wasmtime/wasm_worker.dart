import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../../error/app_error.dart';
import '../sandbox.dart';
import 'wasmtime_engine.dart';
import 'wasmtime_ffi.dart';

/// Worker isolate yang menyimpan engine + modul WASM terkompilasi.
///
/// Satu worker dipakai ulang untuk banyak eksekusi; setiap eksekusi tetap
/// memakai store WASI baru (batas memori dan isolasi antar step). Timeout dan
/// pembatalan menaikkan epoch engine dari isolate utama sehingga loop berhenti
/// lewat trap tanpa mematikan worker.
final class WasmWorker {
  WasmWorker({
    required this.moduleBytes,
    this.libraryPath,
    this.label = 'WASM',
  }) : assert(moduleBytes.isNotEmpty, 'Modul WASM tidak boleh kosong.');

  final Uint8List moduleBytes;

  /// Path library native wasmtime; `null` = resolusi default.
  final String? libraryPath;

  /// Label untuk pesan timeout (mis. `Lua WASM`, `WASM plugin`).
  final String label;

  Isolate? _isolate;
  ReceivePort? _bootstrap;
  ReceivePort? _exit;
  Completer<void>? _exited;
  Completer<void>? _starting;
  SendPort? _commands;
  int? _engineAddress;
  WasmtimeFfi? _watchdog;

  /// Jumlah `incrementEpoch` yang sudah dilakukan pada engine saat ini.
  int _interrupts = 0;

  Future<WasmRunResult> run({
    required List<String> argv,
    Uint8List? stdin,
    required SandboxContext context,
  }) async {
    try {
      await _ensureStarted();
    } on Object catch (error) {
      throw _engineError(context, 'Gagal memuat engine/modul: $error');
    }
    final commands = _commands;
    if (commands == null) {
      throw _engineError(context, 'Worker WASM tidak siap.');
    }

    final reply = ReceivePort();
    final result = Completer<WasmRunResult>();
    var timedOut = false;
    var cancelled = false;
    Timer? timeoutTimer;
    Timer? graceTimer;

    AppError timeoutError() => AppError(
      category: ErrorCategory.runtime,
      code: 'runtime.timeout',
      message:
          '$label melewati batas waktu '
          '${context.config.stepTimeout.inMilliseconds} ms.',
      pluginId: context.pluginId,
      stepId: context.stepId,
    );

    AppError cancelledError() => AppError(
      category: ErrorCategory.cancelled,
      code: 'operation.cancelled',
      message: 'Eksekusi dibatalkan.',
      pluginId: context.pluginId,
      stepId: context.stepId,
    );

    void interrupt() {
      final address = _engineAddress;
      if (address == null) {
        return;
      }
      try {
        _watchdog ??= WasmtimeFfi.open(path: libraryPath);
        WasmtimeEngine.incrementEpochAt(_watchdog!, address);
        _interrupts++;
      } on Object {
        // Bila engine tak bisa dijangkau, grace timer mematikan worker.
      }
    }

    void killWith(AppError error) {
      if (result.isCompleted) {
        return;
      }
      _kill();
      result.completeError(error);
    }

    reply.listen((message) {
      if (result.isCompleted || message is! Map) {
        return;
      }
      if (timedOut) {
        result.completeError(timeoutError());
        return;
      }
      if (cancelled) {
        result.completeError(cancelledError());
        return;
      }
      result.complete(
        WasmRunResult(
          stdout: (message['stdout'] as String?) ?? '',
          stderr: (message['stderr'] as String?) ?? '',
          exitCode: message['exitCode'] as int?,
          errorMessage: message['error'] as String?,
          trapMessage: message['trap'] as String?,
        ),
      );
    });

    commands.send(<String, Object?>{
      'argv': argv,
      'stdin': stdin,
      'memoryLimit': context.config.memoryLimitBytes,
      'deadline': _interrupts + 1,
      'reply': reply.sendPort,
    });

    timeoutTimer = Timer(context.config.stepTimeout, () {
      if (result.isCompleted) {
        return;
      }
      timedOut = true;
      interrupt();
      graceTimer = Timer(
        const Duration(milliseconds: 300),
        () => killWith(timeoutError()),
      );
    });

    final cancellation = context.cancellation;
    if (cancellation != null) {
      unawaited(
        cancellation.whenCancelled.then<void>((_) {
          if (result.isCompleted) {
            return;
          }
          cancelled = true;
          timeoutTimer?.cancel();
          interrupt();
          graceTimer = Timer(
            const Duration(milliseconds: 300),
            () => killWith(cancelledError()),
          );
        }),
      );
    }

    try {
      return await result.future;
    } finally {
      timeoutTimer.cancel();
      graceTimer?.cancel();
      reply.close();
    }
  }

  Future<void> dispose() async {
    final commands = _commands;
    final exited = _exited;
    _commands = null;
    _engineAddress = null;
    if (commands != null) {
      try {
        commands.send(<String, Object?>{'type': 'close'});
      } on Object {
        // Isolate mungkin sudah mati.
      }
    }

    if (exited != null) {
      try {
        await exited.future.timeout(const Duration(milliseconds: 300));
      } on TimeoutException {
        _isolate?.kill(priority: Isolate.immediate);
      }
    } else {
      _isolate?.kill(priority: Isolate.immediate);
    }

    _isolate = null;
    _closePorts();
    _starting = null;
    _interrupts = 0;
  }

  Future<void> _ensureStarted() {
    if (_commands != null) {
      return Future<void>.value();
    }
    final starting = _starting;
    if (starting != null) {
      return starting.future;
    }

    final completer = Completer<void>();
    _starting = completer;

    final bootstrap = ReceivePort();
    final exit = ReceivePort();
    _bootstrap = bootstrap;
    _exit = exit;
    final exited = Completer<void>();
    _exited = exited;
    exit.listen((_) {
      if (!exited.isCompleted) {
        exited.complete();
      }
      _commands = null;
      _engineAddress = null;
    });

    void fail(String message) {
      if (!completer.isCompleted) {
        completer.completeError(WasmtimeException(message));
      }
    }

    bootstrap.listen((message) {
      if (message is! Map) {
        return;
      }
      switch (message['type']) {
        case 'ready':
          final port = message['port'];
          final engine = message['engine'];
          if (port is! SendPort || engine is! int) {
            fail('Protokol worker WASM tidak valid.');
            return;
          }
          _commands = port;
          _engineAddress = engine;
          _interrupts = 0;
          if (!completer.isCompleted) {
            completer.complete();
          }
        case 'error':
          fail((message['message'] as String?) ?? 'Worker WASM gagal.');
      }
    });

    unawaited(() async {
      try {
        _isolate = await Isolate.spawn<List<Object?>>(
          _wasmWorkerMain,
          <Object?>[bootstrap.sendPort, moduleBytes, libraryPath],
          onExit: exit.sendPort,
          errorsAreFatal: false,
        );
        await completer.future;
      } on Object catch (error) {
        _starting = null;
        _commands = null;
        _engineAddress = null;
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      }
    }());

    return completer.future.whenComplete(() {
      _starting = null;
    });
  }

  void _kill() {
    final isolate = _isolate;
    _isolate = null;
    _commands = null;
    _engineAddress = null;
    _interrupts = 0;
    isolate?.kill(priority: Isolate.immediate);
    _closePorts();
  }

  void _closePorts() {
    _bootstrap?.close();
    _bootstrap = null;
    _exit?.close();
    _exit = null;
    _exited = null;
  }

  static AppError _engineError(SandboxContext context, String message) {
    return AppError(
      category: ErrorCategory.runtime,
      code: 'runtime.wasm_error',
      message: 'WASM: $message',
      pluginId: context.pluginId,
      stepId: context.stepId,
    );
  }
}

Future<void> _wasmWorkerMain(List<Object?> init) async {
  final bootstrap = init[0] as SendPort;
  final moduleBytes = init[1] as Uint8List;
  final libraryPath = init[2] as String?;
  final commands = ReceivePort();
  WasmtimeEngine? engine;
  WasmtimeModule? module;

  try {
    final ffi = WasmtimeFfi.open(path: libraryPath);
    engine = WasmtimeEngine(ffi: ffi);
    module = engine.compile(moduleBytes);
    bootstrap.send(<String, Object?>{
      'type': 'ready',
      'port': commands.sendPort,
      'engine': engine.address,
    });

    await for (final message in commands) {
      if (message is! Map) {
        continue;
      }
      if (message['type'] == 'close') {
        break;
      }
      final reply = message['reply'];
      if (reply is! SendPort) {
        continue;
      }
      final rawArgv = message['argv'];
      final argv = rawArgv is List
          ? rawArgv.whereType<String>().toList(growable: false)
          : const <String>[];
      final stdin = message['stdin'] as Uint8List?;
      final memoryLimit = message['memoryLimit'] as int? ?? 64 * 1024 * 1024;
      final deadline = message['deadline'] as int? ?? 1;

      try {
        final run = engine.run(
          module,
          argv,
          memoryLimitBytes: memoryLimit,
          epochDeadline: deadline,
          stdinBytes: stdin,
        );
        reply.send(<String, Object?>{
          'stdout': run.stdout,
          'stderr': run.stderr,
          'exitCode': run.exitCode,
          'error': run.errorMessage,
          'trap': run.trapMessage,
        });
      } on Object catch (error) {
        reply.send(<String, Object?>{'error': error.toString()});
      }
    }
  } on Object catch (error) {
    bootstrap.send(<String, Object?>{
      'type': 'error',
      'message': error.toString(),
    });
  } finally {
    module?.close();
    engine?.close();
    commands.close();
  }
}
