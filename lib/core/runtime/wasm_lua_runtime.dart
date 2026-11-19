import 'dart:typed_data';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import '../plugin/plugin_permission.dart';
import 'lua_program.dart';
import 'sandbox.dart';
import 'wasmtime/wasm_worker.dart';

/// Runtime tier `lua` di atas WASI (`lua_runtime.wasm`) memakai wasmtime.
///
/// Engine + modul dikompilasi sekali lalu dipakai ulang oleh worker isolate
/// (satu per instans runtime). Setiap eksekusi tetap memakai store WASI baru
/// sehingga memori dibatasi dan tidak bocor antar step. Timeout/pembatalan
/// menaikkan epoch engine dari isolate utama; loop Lua berhenti lewat trap
/// tanpa mematikan worker.
final class WasmLuaRuntime implements SandboxRuntime, DisposableSandboxRuntime {
  WasmLuaRuntime({
    required this.source,
    required this.moduleBytes,
    this.libraryPath,
  }) : assert(moduleBytes.isNotEmpty, 'Modul WASM tidak boleh kosong.');

  /// Sumber Lua plugin (sama seperti `LuaRuntime`).
  final String source;

  /// Byte `lua_runtime.wasm` (WASI + exception handling).
  final Uint8List moduleBytes;

  /// Path library native wasmtime; `null` = resolusi default.
  final String? libraryPath;

  WasmWorker? _worker;
  var _disposed = false;

  @override
  Future<Buffer> execute(
    Buffer input,
    Map<String, Object?> args,
    SandboxContext context,
  ) async {
    context.ensureActive();
    context.requirePermission(PluginPermission.cpu);
    if (_disposed) {
      throw AppError(
        category: ErrorCategory.runtime,
        code: 'runtime.disposed',
        message: 'Runtime WASM sudah dilepas.',
        pluginId: context.pluginId,
        stepId: context.stepId,
      );
    }
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
    final worker = _worker ??= WasmWorker(
      moduleBytes: moduleBytes,
      libraryPath: libraryPath,
      label: 'Lua WASM',
    );
    final result = await worker.run(
      argv: <String>['lua', '-e', script],
      context: context,
    );
    if (!result.isSuccess) {
      final message = result.failureMessage;
      if (result.exitCode == null) {
        throw AppError(
          category: ErrorCategory.runtime,
          code: 'runtime.wasm_error',
          message: 'WASM: $message',
          pluginId: context.pluginId,
          stepId: context.stepId,
        );
      }
      throw AppError(
        category: ErrorCategory.runtime,
        code: 'runtime.lua_error',
        message: 'Lua: $message',
        pluginId: context.pluginId,
        stepId: context.stepId,
      );
    }
    return TextBuffer(_stripTrailingNewline(result.stdout));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final worker = _worker;
    _worker = null;
    await worker?.dispose();
  }

  /// `print(__bufferite_entry())` menambahkan newline; hapus satu agar
  /// semantik sama dengan runtime `lua_dart`.
  static String _stripTrailingNewline(String text) {
    if (text.endsWith('\n')) {
      return text.substring(0, text.length - 1);
    }
    return text;
  }
}
