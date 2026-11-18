import 'dart:async';

import 'package:lua_dart/lua_dart.dart';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import 'sandbox.dart';

/// Runtime Lua murni (tier `lua`) memakai `lua_dart` (FFI, Lua 5.5.1).
///
/// Source plugin harus mendefinisikan `transform(input, args)` dan boleh
/// mengembalikan string atau mencetak lewat `print`. Library dibuka dengan
/// `sandbox: true`: tanpa `io`, `dofile`, `loadfile`, dan fungsi `os` yang
/// menyentuh host.
final class LuaRuntime implements SandboxRuntime {
  LuaRuntime(this.source);

  final String source;

  static Future<void>? _loaded;

  static Future<void> _ensureLoaded() {
    return _loaded ??= LuaState.loadRuntime();
  }

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

    await _ensureLoaded();
    context.ensureActive();

    final state = LuaState.newState(
      memoryLimit: context.config.memoryLimitBytes,
    );
    try {
      state.openLibs(sandbox: true);
      final chunk = _wrapSource(source, input.asText(), args);
      if (!state.doString(chunk, chunkName: 'bufferite_transform')) {
        throw _luaError(context, state.toStr(-1) ?? 'Kesalahan Lua.');
      }
      final result = state.toStr(-1) ?? '';
      return TextBuffer(result);
    } on AppError {
      rethrow;
    } on Object catch (error) {
      throw _luaError(context, error.toString());
    } finally {
      state.close();
    }
  }

  AppError _luaError(SandboxContext context, String message) {
    return AppError(
      category: ErrorCategory.runtime,
      code: 'runtime.lua_error',
      message: 'Lua: $message',
      pluginId: context.pluginId,
      stepId: context.stepId,
    );
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
