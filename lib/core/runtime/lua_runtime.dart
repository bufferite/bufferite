import 'dart:async';
import 'dart:isolate';

import 'package:lua_dart/lua_dart.dart';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import 'sandbox.dart';

/// Runtime Lua murni (tier `lua`) memakai `lua_dart` (Lua 5.5.1).
///
/// Eksekusi berjalan di isolate kerja; timeout/pembatalan memakai
/// `LuaInterruptHandle` (grace 300 ms sebelum isolate dimatikan). Source plugin
/// harus mendefinisikan `transform(input, args)` dan boleh mengembalikan string
/// atau mencetak lewat `print`. Library dibuka dengan `sandbox: true`: tanpa
/// `io`, `dofile`, `loadfile`, `package`, `require`, `debug`, dan fungsi `os`
/// yang menyentuh host.
final class LuaRuntime implements SandboxRuntime {
  LuaRuntime(this.source);

  final String source;

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
        message: 'Buffer file harus dimaterialisasi sebelum runtime Lua.',
        pluginId: context.pluginId,
        stepId: context.stepId,
      );
    }

    return TextBuffer(await _runIsolated(input.asText(), args, context));
  }

  Future<String> _runIsolated(
    String input,
    Map<String, Object?> args,
    SandboxContext context,
  ) {
    final receive = ReceivePort();
    final result = Completer<String>();
    Isolate? isolate;
    int? interruptAddress;
    Timer? timeoutTimer;
    Timer? graceTimer;
    var timedOut = false;
    var cancelled = false;

    void interrupt() {
      final address = interruptAddress;
      if (address != null) {
        LuaInterruptHandle.receive(
          SharedLuaInterruptHandle.fromAddress(address),
        ).trigger();
      }
    }

    void fail(AppError error) {
      if (!result.isCompleted) {
        result.completeError(error);
      }
    }

    void scheduleKill(AppError error) {
      graceTimer?.cancel();
      graceTimer = Timer(const Duration(milliseconds: 300), () {
        isolate?.kill(priority: Isolate.immediate);
        fail(error);
      });
    }

    receive.listen((message) {
      if (message is! Map<Object?, Object?>) {
        return;
      }
      switch (message['type']) {
        case 'ready':
          interruptAddress = message['handle'] as int?;
          final port = message['port'];
          if (port is! SendPort) {
            fail(_error(context, 'Protokol isolate Lua tidak valid.'));
            return;
          }
          port.send(<String, Object?>{
            'source': source,
            'input': input,
            'args': args,
            'memoryLimit': context.config.memoryLimitBytes,
          });
          timeoutTimer = Timer(context.config.stepTimeout, () {
            timedOut = true;
            interrupt();
            scheduleKill(
              AppError(
                category: ErrorCategory.runtime,
                code: 'runtime.timeout',
                message:
                    'Lua melewati batas waktu '
                    '${context.config.stepTimeout.inMilliseconds} ms.',
                pluginId: context.pluginId,
                stepId: context.stepId,
              ),
            );
          });
        case 'result':
          if (timedOut) {
            fail(
              AppError(
                category: ErrorCategory.runtime,
                code: 'runtime.timeout',
                message:
                    'Lua melewati batas waktu '
                    '${context.config.stepTimeout.inMilliseconds} ms.',
                pluginId: context.pluginId,
                stepId: context.stepId,
              ),
            );
            return;
          }
          if (cancelled) {
            fail(_cancelled(context));
            return;
          }
          if (message['ok'] == true) {
            if (!result.isCompleted) {
              result.complete((message['text'] as String?) ?? '');
            }
          } else {
            fail(
              _error(
                context,
                (message['error'] as String?) ?? 'Kesalahan Lua.',
              ),
            );
          }
        case 'error':
          fail(
            _error(context, (message['message'] as String?) ?? 'Kesalahan.'),
          );
      }
    });

    unawaited(
      context.cancellation?.whenCancelled.then<void>((_) {
        cancelled = true;
        interrupt();
        scheduleKill(_cancelled(context));
      }),
    );

    unawaited(() async {
      try {
        isolate = await Isolate.spawn(_luaIsolateMain, receive.sendPort);
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

Future<void> _luaIsolateMain(SendPort mainPort) async {
  final inbox = ReceivePort();
  final handle = LuaInterruptHandle();
  try {
    mainPort.send(<String, Object?>{
      'type': 'ready',
      'port': inbox.sendPort,
      'handle': handle.share().address,
    });

    final message = await inbox.first;
    if (message is! Map<Object?, Object?>) {
      return;
    }
    final source = message['source'] as String? ?? '';
    final input = message['input'] as String? ?? '';
    final args =
        message['args'] as Map<String, Object?>? ?? const <String, Object?>{};
    final memoryLimit = message['memoryLimit'] as int? ?? 64 * 1024 * 1024;

    await LuaState.loadRuntime();
    final state = LuaState.newState(memoryLimit: memoryLimit);
    state.attachInterruptHandle(handle);
    try {
      state.openLibs(sandbox: true);
      final ok = state.doString(
        _wrapSource(source, input, args),
        chunkName: 'bufferite_transform',
      );
      final text = state.toStr(-1) ?? '';
      mainPort.send(<String, Object?>{
        'type': 'result',
        'ok': ok,
        'text': ok ? text : null,
        'error': ok ? null : text,
      });
    } finally {
      state.close();
    }
  } on Object catch (error) {
    mainPort.send(<String, Object?>{
      'type': 'error',
      'message': error.toString(),
    });
  } finally {
    inbox.close();
  }
}

String _wrapSource(String source, String input, Map<String, Object?> args) {
  return '''
local __out = {}
local __print = print
print = function(...)
  local n = select('#', ...)
  local parts = {}
  for i = 1, n do parts[i] = tostring((select(i, ...))) end
  __out[#__out + 1] = table.concat(parts, '\\t')
end
$source
function __bufferite_entry()
  if type(transform) ~= 'function' then
    error('transform(input, args) tidak didefinisikan', 2)
  end
  local ok, res = pcall(transform, ${_luaString(input)}, ${_luaValue(args)})
  print = __print
  if not ok then error(res, 0) end
  if type(res) == 'string' then return res end
  if #__out == 0 then return '' end
  return table.concat(__out, '\\n') .. '\\n'
end
return __bufferite_entry()
''';
}

String _luaString(String value) {
  final buffer = StringBuffer('"');
  for (final rune in value.runes) {
    switch (rune) {
      case 0x5C:
        buffer.write(r'\\');
      case 0x22:
        buffer.write(r'\"');
      case 0x0A:
        buffer.write(r'\n');
      case 0x0D:
        buffer.write(r'\r');
      case 0x09:
        buffer.write(r'\t');
      default:
        if (rune < 0x20) {
          buffer.write('\\${rune.toString().padLeft(3, '0')}');
        } else {
          buffer.writeCharCode(rune);
        }
    }
  }
  buffer.write('"');
  return buffer.toString();
}

String _luaValue(Object? value) {
  if (value == null) {
    return 'nil';
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  if (value is num) {
    return value.toString();
  }
  if (value is String) {
    return _luaString(value);
  }
  if (value is List<Object?>) {
    return '<${value.map(_luaValue).join(', ')}>';
  }
  if (value is Map<String, Object?>) {
    return '{${value.entries.map((entry) => '[${_luaString(entry.key)}] = ${_luaValue(entry.value)}').join(', ')}}';
  }
  return _luaString(value.toString());
}
