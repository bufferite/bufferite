import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../engine/buffer.dart';
import '../error/app_error.dart';
import '../plugin/installed_plugin.dart';
import '../plugin/operation.dart';
import '../plugin/operation_param.dart';
import '../plugin/plugin_integrity.dart';
import '../plugin/plugin_manifest.dart';
import '../plugin/plugin_permission.dart';
import 'dsl_runtime.dart';
import 'lua_runtime.dart';
import 'sandbox.dart';
import 'wasm_lua_runtime.dart';

/// Engine untuk tier `lua`.
///
/// [native] memakai `lua_dart` (Lua di host, isolasi kapsabilitas saja).
/// [wasm] menjalankan Lua di dalam `lua_runtime.wasm` memakai wasmtime.
enum LuaEngine { native, wasm }

/// Sumber daya engine `wasm` untuk tier `lua`.
final class WasmLuaModule {
  WasmLuaModule({required this.bytes, this.libraryPath})
    : assert(bytes.isNotEmpty, 'Modul WASM tidak boleh kosong.');

  /// Byte `lua_runtime.wasm`.
  final Uint8List bytes;

  /// Path library native wasmtime; `null` = resolusi default platform.
  final String? libraryPath;
}

/// Pembaca byte entrypoint plugin. Bisa diganti di test.
typedef PluginEntrypointReader =
    Future<Uint8List> Function(String absolutePath);

/// Membungkus [SandboxRuntime] menjadi [Operation] agar bisa dipanggil mesin
/// pipeline.
///
/// Runtime dimuat malas pada eksekusi pertama lalu dipakai ulang, sehingga
/// registrasi plugin tetap sinkron dan file plugin hanya dibaca saat perlu.
final class SandboxOperation implements Operation {
  SandboxOperation({
    required this.descriptor,
    required this.createRuntime,
    required this.sandboxConfig,
  });

  final OperationDescriptor descriptor;
  final Future<SandboxRuntime> Function() createRuntime;
  final SandboxConfig Function() sandboxConfig;

  Future<SandboxRuntime>? _pending;

  @override
  String get id => descriptor.id;

  @override
  String get name => descriptor.name;

  @override
  OperationCategory get category => descriptor.category;

  @override
  List<OperationParam> get params => descriptor.params;

  @override
  OperationIO get io => descriptor.io;

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    final runtime = await _runtime();
    return runtime.execute(
      input,
      args,
      SandboxContext(
        pluginId: descriptor.pluginId,
        operationId: descriptor.id,
        config: sandboxConfig(),
      ),
    );
  }

  Future<SandboxRuntime> _runtime() async {
    final pending = _pending;
    if (pending != null) {
      return pending;
    }
    final created = createRuntime();
    _pending = created;
    try {
      return await created;
    } on Object {
      // Jangan cache kegagalan; perbaikan file/manifest harus bisa dicoba lagi.
      if (identical(_pending, created)) {
        _pending = null;
      }
      rethrow;
    }
  }
}

/// Membangun executor operasi plugin dari entrypoint yang terpasang.
///
/// Tier yang didukung saat ini: `dsl` dan `lua` (native atau WASM). Tier
/// `wasm` belum punya ABI plugin sehingga belum menghasilkan executor.
final class PluginRuntimeLoader {
  PluginRuntimeLoader({
    required this.sandboxConfig,
    this.luaEngine = LuaEngine.native,
    this.wasmModule,
    PluginEntrypointReader? readEntrypoint,
  }) : _readEntrypoint = readEntrypoint ?? _readFile;

  final SandboxConfig Function() sandboxConfig;
  final LuaEngine luaEngine;
  final WasmLuaModule? wasmModule;
  final PluginEntrypointReader _readEntrypoint;

  /// Executor untuk [operation], atau `null` bila tier belum didukung/belum
  /// terpasang.
  Operation? operationFor(InstalledPlugin plugin, ManifestOperation operation) {
    final installPath = plugin.installPath;
    if (installPath == null) {
      return null;
    }
    final tier = plugin.manifest.tier;
    if (tier == RuntimeTier.wasm) {
      // ABI plugin WASM belum didefinisikan (F05-T06, 1.1).
      return null;
    }
    return SandboxOperation(
      descriptor: operation.toDescriptor(
        pluginId: plugin.manifest.pluginId,
        pluginVersion: plugin.manifest.version,
        tier: tier,
      ),
      createRuntime: () => _loadRuntime(plugin, installPath),
      sandboxConfig: _configFor(plugin.manifest),
    );
  }

  SandboxConfig Function() _configFor(PluginManifest manifest) {
    return () {
      final base = sandboxConfig();
      return SandboxConfig(
        stepTimeout: base.stepTimeout,
        memoryLimitBytes: base.memoryLimitBytes,
        permissions: <PluginPermission>{
          ...base.permissions,
          ...manifest.permissions,
        },
      );
    };
  }

  Future<SandboxRuntime> _loadRuntime(
    InstalledPlugin plugin,
    String installPath,
  ) async {
    final manifest = plugin.manifest;
    final entry = manifest.entrypoint;
    final path = '$installPath/$entry';

    final Uint8List bytes;
    try {
      bytes = await _readEntrypoint(path);
    } on FileSystemException catch (error) {
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.entrypoint_missing',
        message: 'Entrypoint ${manifest.entrypoint} tidak bisa dibaca.',
        details: <String, Object?>{'path': path, 'error': error.message},
      );
    }

    final integrity = manifest.integritySha256;
    if (integrity != null) {
      PluginIntegrity.verifyOrThrow(
        bytes: bytes,
        expected: integrity,
        subject: manifest.entrypoint,
      );
    }

    final source = _decodeUtf8(bytes, manifest.entrypoint);
    switch (manifest.tier) {
      case RuntimeTier.dsl:
        return DslRuntime.parse(source);
      case RuntimeTier.lua:
        if (luaEngine == LuaEngine.wasm) {
          final module = wasmModule;
          if (module == null) {
            throw AppError(
              category: ErrorCategory.runtime,
              code: 'runtime.wasm_unavailable',
              message: 'Engine Lua WASM belum tersedia di build ini.',
              pluginId: manifest.pluginId,
              details: <String, Object?>{'entrypoint': manifest.entrypoint},
            );
          }
          return WasmLuaRuntime(
            source: source,
            moduleBytes: module.bytes,
            libraryPath: module.libraryPath,
          );
        }
        return LuaRuntime(source);
      case RuntimeTier.wasm:
        throw AppError(
          category: ErrorCategory.unsupported,
          code: 'runtime.tier_unsupported',
          message: 'Tier wasm belum didukung pada versi ini.',
          pluginId: manifest.pluginId,
        );
    }
  }

  static String _decodeUtf8(Uint8List bytes, String entrypoint) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw AppError(
        category: ErrorCategory.plugin,
        code: 'plugin.entrypoint_invalid',
        message: 'Entrypoint $entrypoint bukan teks UTF-8.',
        details: <String, Object?>{'entrypoint': entrypoint},
      );
    }
  }

  static Future<Uint8List> _readFile(String path) {
    return File(path).readAsBytes();
  }
}
