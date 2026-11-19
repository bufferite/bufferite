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
import 'runtime_cache.dart';
import 'sandbox.dart';
import 'wasm_lua_runtime.dart';
import 'wasm_plugin_runtime.dart';

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
/// Runtime diambil dari [RuntimeCache] per plugin, sehingga source/entrypoint
/// dibaca dan modul WASM dikompilasi sekali selama cache hidup.
final class SandboxOperation implements Operation {
  SandboxOperation({
    required this.descriptor,
    required this.createRuntime,
    required this.sandboxConfig,
    required this.cache,
  });

  final OperationDescriptor descriptor;
  final Future<SandboxRuntime> Function() createRuntime;
  final SandboxConfig Function() sandboxConfig;
  final RuntimeCache cache;

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
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) {
    final context = SandboxContext(
      pluginId: descriptor.pluginId,
      operationId: descriptor.id,
      config: sandboxConfig(),
    );
    return cache.use(
      descriptor.pluginId,
      createRuntime,
      (runtime) => runtime.execute(input, args, context),
    );
  }
}

/// Membangun executor operasi plugin dari entrypoint yang terpasang.
///
/// Tier yang didukung: `dsl`, `lua` (native atau WASM), dan `wasm` (ABI
/// command WASI, lihat `WasmPluginRuntime`).
final class PluginRuntimeLoader {
  PluginRuntimeLoader({
    required this.sandboxConfig,
    this.luaEngine = LuaEngine.native,
    this.wasmModule,
    this.wasmtimeLibraryPath,
    RuntimeCache? cache,
    PluginEntrypointReader? readEntrypoint,
  }) : cache = cache ?? RuntimeCache(),
       _readEntrypoint = readEntrypoint ?? _readFile;

  final SandboxConfig Function() sandboxConfig;
  final LuaEngine luaEngine;
  final WasmLuaModule? wasmModule;

  /// Path library wasmtime untuk tier `wasm`; `null` = default platform.
  final String? wasmtimeLibraryPath;
  final RuntimeCache cache;
  final PluginEntrypointReader _readEntrypoint;

  /// Lepas runtime plugin (nonaktif/hapus) agar worker/engine WASM berhenti.
  Future<void> evictPlugin(String pluginId) => cache.evict(pluginId);

  /// Lepas semua runtime (shutdown/test).
  Future<void> dispose() => cache.dispose();

  /// Executor untuk [operation], atau `null` bila tier belum didukung/belum
  /// terpasang.
  Operation? operationFor(InstalledPlugin plugin, ManifestOperation operation) {
    final installPath = plugin.installPath;
    if (installPath == null) {
      return null;
    }
    final tier = plugin.manifest.tier;
    return SandboxOperation(
      descriptor: operation.toDescriptor(
        pluginId: plugin.manifest.pluginId,
        pluginVersion: plugin.manifest.version,
        tier: tier,
      ),
      createRuntime: () => _loadRuntime(plugin, installPath),
      sandboxConfig: _configFor(plugin.manifest),
      cache: cache,
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

    switch (manifest.tier) {
      case RuntimeTier.dsl:
        return DslRuntime.parse(_decodeUtf8(bytes, manifest.entrypoint));
      case RuntimeTier.lua:
        final source = _decodeUtf8(bytes, manifest.entrypoint);
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
        return WasmPluginRuntime(
          moduleBytes: bytes,
          libraryPath: wasmtimeLibraryPath,
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
