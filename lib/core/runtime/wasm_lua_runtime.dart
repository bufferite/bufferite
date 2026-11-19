import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import 'lua_program.dart';
import 'sandbox.dart';
import 'wasmtime/wasmtime_engine.dart';
import 'wasmtime/wasmtime_ffi.dart';

/// Runtime tier `wasm` untuk plugin Lua yang dikompilasi ke WASI
/// (`lua_runtime.wasm`).
///
/// Eksekusi berjalan di isolate kerja memakai engine wasmtime. Timeout dan
/// pembatalan ditegakkan dengan menaikkan epoch engine dari isolate utama,
/// sehingga loop Lua yang tak berujung berhenti lewat trap tanpa memblokir UI.
final class WasmLuaRuntime implements SandboxRuntime {
  WasmLuaRuntime({
    required this.source,
    required this.moduleBytes,
    this.libraryPath,
  }) : assert(moduleBytes.isNotEmpty, 'Modul WASM tidak boleh kosong.');

  /// Sumber Lua plugin (sama seperti [LuaRuntime]).
  final String source;

  /// Byte `lua_runtime.wasm` (WASI + exception handling).
  final Uint8List moduleBytes;

  /// Path library native wasmtime; `null` = resolusi default.
  final String? libraryPath;

  @override
  Future<Buffer> execute(
    Buffer input,
    Map<String, Object?> args,
    SandboxContext context,
  ) async {
    context.ensureActive();
    if (input.kind == BufferKind.file) {
      throw AppError(
        category: ErrorCategory.runtime,
        code: 'runtime.file_not_materialized',
        message: 'Buffer file harus dimaterialisasi sebelum runtime WASM.',
        pluginId: context.pluginId,
        stepId: context.stepId,
      );
    }

    final script = buildLuaTransformScript(
      source,
      input.asText(),
      args,
      printResult: true,
      sandbox: true,
    );
    return TextBuffer(_stripTrailingNewline(await _runIsolated(script, context)));
  }

  /// `print(__bufferite_entry())` menambahkan newline; hapus satu agar
  /// semantik sama dengan runtime `lua_dart`.
  static String _stripTrailingNewline(String text) {
    if (text.endsWith('\n')) {
      return text.substring(0, text.length - 1);
    }
    return text;
  }

  Future<String> _runIsolated(String script, SandboxContext context) {
    final receive = ReceivePort();
    final result = Completer<String>();
    Isolate? isolate;
    int? engineAddress;
    Timer? timeoutTimer;
    Timer? graceTimer;
    var timedOut = false;
    var cancelled = false;
    WasmtimeFfi? watchdog;

    AppError timeoutError() => AppError(
      category: ErrorCategory.runtime,
      code: 'runtime.timeout',
      message:
          'Lua WASM melewati batas waktu '
          '${context.config.stepTimeout.inMilliseconds} ms.',
      pluginId: context.pluginId,
      stepId: context.stepId,
    );

    void fail(AppError error) {
      if (!result.isCompleted) {
        result.completeError(error);
      }
    }

    void interrupt() {
      final address = engineAddress;
      if (address == null) {
        return;
      }
      try {
        watchdog ??= WasmtimeFfi.open(path: libraryPath);
        WasmtimeEngine.incrementEpochAt(watchdog!, address);
      } on Object {
        // Bila engine tak bisa dijangkau, grace timer mematikan isolate.
      }
    }

    void scheduleKill(AppError error) {
      graceTimer?.cancel();
      graceTimer = Timer(const Duration(milliseconds: 300), () {
        isolate?.kill(priority: Isolate.immediate);
        fail(error);
      });
    }

    void onDeadline() {
      if (timedOut || cancelled || result.isCompleted) {
        return;
      }
      timedOut = true;
      interrupt();
      scheduleKill(timeoutError());
    }

    receive.listen((message) {
      if (message is! Map<Object?, Object?>) {
        return;
      }
      switch (message['type']) {
        case 'ready':
          engineAddress = message['engine'] as int?;
          final port = message['port'];
          if (port is! SendPort) {
            fail(_error(context, 'Protokol isolate WASM tidak valid.'));
            return;
          }
          port.send(<String, Object?>{
            'script': script,
            'memoryLimit': context.config.memoryLimitBytes,
          });
          timeoutTimer = Timer(context.config.stepTimeout, onDeadline);
        case 'result':
          if (cancelled) {
            fail(_cancelled(context));
            return;
          }
          if (timedOut) {
            fail(timeoutError());
            return;
          }
          if (message['ok'] == true) {
            if (!result.isCompleted) {
              result.complete((message['text'] as String?) ?? '');
            }
            return;
          }
          final kind = message['kind'] as String?;
          if (kind == 'engine') {
            fail(
              AppError(
                category: ErrorCategory.runtime,
                code: 'runtime.wasm_error',
                message:
                    'WASM: ${(message['error'] as String?) ?? 'kesalahan engine.'}',
                pluginId: context.pluginId,
                stepId: context.stepId,
              ),
            );
          } else {
            fail(
              _error(context, (message['error'] as String?) ?? 'Kesalahan Lua.'),
            );
          }
        case 'error':
          fail(_error(context, (message['message'] as String?) ?? 'Kesalahan.'));
      }
    });

    unawaited(
      context.cancellation?.whenCancelled.then<void>((_) {
        if (cancelled || result.isCompleted) {
          return;
        }
        cancelled = true;
        timeoutTimer?.cancel();
        interrupt();
        scheduleKill(_cancelled(context));
      }),
    );

    unawaited(() async {
      try {
        isolate = await Isolate.spawn<List<Object?>>(_wasmIsolateMain, <Object?>[
          receive.sendPort,
          moduleBytes,
          libraryPath,
        ]);
        await result.future;
      } on Object catch (error) {
        if (!result.isCompleted) {
          result.completeError(error);
        }
      }
    }());

    return result.future.whenComplete(() {
      timeoutTimer?.cancel();
      graceTimer?.cancel();
      isolate?.kill(priority: Isolate.beforeNextEvent);
      receive.close();
    });
  }

  AppError _error(SandboxContext context, String message) {
    return AppError(
      category: ErrorCategory.runtime,
      code: 'runtime.lua_error',
      message: 'Lua: $message',
      pluginId: context.pluginId,
      stepId: context.stepId,
    );
  }

  AppError _cancelled(SandboxContext context) {
    return AppError(
      category: ErrorCategory.cancelled,
      code: 'operation.cancelled',
      message: 'Eksekusi dibatalkan.',
      pluginId: context.pluginId,
      stepId: context.stepId,
    );
  }
}

Future<void> _wasmIsolateMain(List<Object?> init) async {
  final mainPort = init[0] as SendPort;
  final moduleBytes = init[1] as Uint8List;
  final libraryPath = init[2] as String?;
  final inbox = ReceivePort();
  WasmtimeEngine? engine;

  try {
    final ffi = WasmtimeFfi.open(path: libraryPath);
    engine = WasmtimeEngine(ffi: ffi);
    final module = engine.compile(moduleBytes);
    try {
      mainPort.send(<String, Object?>{
        'type': 'ready',
        'port': inbox.sendPort,
        'engine': engine.address,
      });

      final message = await inbox.first;
      if (message is! Map<Object?, Object?>) {
        return;
      }
      final script = message['script'] as String? ?? '';
      final memoryLimit = message['memoryLimit'] as int? ?? 64 * 1024 * 1024;

      final run = engine.run(
        module,
        <String>['lua', '-e', script],
        memoryLimitBytes: memoryLimit,
      );

      if (run.isSuccess) {
        mainPort.send(<String, Object?>{
          'type': 'result',
          'ok': true,
          'text': run.stdout,
        });
      } else if (run.exitCode == null) {
        mainPort.send(<String, Object?>{
          'type': 'result',
          'ok': false,
          'kind': 'engine',
          'error': run.failureMessage,
        });
      } else {
        mainPort.send(<String, Object?>{
          'type': 'result',
          'ok': false,
          'kind': 'lua',
          'error': run.failureMessage,
        });
      }
    } finally {
      module.close();
    }
  } on Object catch (error) {
    mainPort.send(<String, Object?>{
      'type': 'result',
      'ok': false,
      'kind': 'engine',
      'error': error.toString(),
    });
  } finally {
    engine?.close();
    inbox.close();
  }
}
