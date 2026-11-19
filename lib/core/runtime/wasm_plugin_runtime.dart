import 'dart:convert';
import 'dart:typed_data';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import '../plugin/plugin_permission.dart';
import 'sandbox.dart';
import 'wasmtime/wasm_worker.dart';

/// Runtime tier `wasm`: modul WASI mandiri milik plugin.
///
/// ABI (versi 1):
/// - Modul harus mengekspor `_start` (WASI command).
/// - `argv[0]` = nama modul, `argv[1]` = id operasi, `argv[2]` = args JSON.
/// - Input teks dikirim lewat **stdin** (UTF-8).
/// - Output teks = stdout; satu newline di akhir dihapus.
/// - Exit code 0 = sukses; selain itu stderr menjadi pesan error.
///
/// Tidak ada host function net/fs: linker hanya menyediakan WASI preview1
/// tanpa preopen direktori dan tanpa socket. Izin `net`/`file:*` di manifest
/// tidak menambah capability apa pun pada ABI ini.
final class WasmPluginRuntime
    implements SandboxRuntime, DisposableSandboxRuntime {
  WasmPluginRuntime({
    required this.moduleBytes,
    this.libraryPath,
  }) : assert(moduleBytes.isNotEmpty, 'Modul WASM tidak boleh kosong.');

  final Uint8List moduleBytes;

  /// Path library native wasmtime; `null` = resolusi default platform.
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

    final worker = _worker ??= WasmWorker(
      moduleBytes: moduleBytes,
      libraryPath: libraryPath,
      label: 'WASM plugin',
    );
    final result = await worker.run(
      argv: <String>[
        'plugin.wasm',
        context.operationId,
        jsonEncode(args),
      ],
      stdin: Uint8List.fromList(utf8.encode(input.asText())),
      context: context,
    );
    if (!result.isSuccess) {
      throw AppError(
        category: ErrorCategory.runtime,
        code: 'runtime.wasm_error',
        message: 'WASM plugin: ${result.failureMessage}',
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

  static String _stripTrailingNewline(String text) {
    if (text.endsWith('\n')) {
      return text.substring(0, text.length - 1);
    }
    return text;
  }
}
