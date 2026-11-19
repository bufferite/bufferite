import '../engine/buffer.dart';
import '../engine/pipeline.dart';
import '../error/app_error.dart';
import '../plugin/plugin_permission.dart';

/// Batas resource dan izin untuk satu eksekusi plugin.
final class SandboxConfig {
  SandboxConfig({
    this.stepTimeout = const Duration(seconds: 2),
    this.memoryLimitBytes = 64 * 1024 * 1024,
    Set<PluginPermission> permissions = const <PluginPermission>{
      PluginPermission.cpu,
    },
  }) : permissions = Set<PluginPermission>.unmodifiable(<PluginPermission>{
         PluginPermission.cpu,
         ...permissions,
       }) {
    if (stepTimeout <= Duration.zero) {
      throw ArgumentError.value(
        stepTimeout,
        'stepTimeout',
        'Batas waktu harus lebih dari nol.',
      );
    }
    if (memoryLimitBytes <= 0) {
      throw ArgumentError.value(
        memoryLimitBytes,
        'memoryLimitBytes',
        'Batas memori harus lebih dari nol.',
      );
    }
  }

  static final SandboxConfig defaults = SandboxConfig();

  final Duration stepTimeout;
  final int memoryLimitBytes;

  /// Izin aktif. `cpu` selalu ada.
  final Set<PluginPermission> permissions;

  SandboxConfig copyWith({
    Duration? stepTimeout,
    int? memoryLimitBytes,
    Set<PluginPermission>? permissions,
  }) {
    return SandboxConfig(
      stepTimeout: stepTimeout ?? this.stepTimeout,
      memoryLimitBytes: memoryLimitBytes ?? this.memoryLimitBytes,
      permissions: permissions ?? this.permissions,
    );
  }
}

/// Identitas dan resource untuk satu pemanggilan runtime.
final class SandboxContext {
  SandboxContext({
    required this.pluginId,
    required this.operationId,
    required this.config,
    this.stepId,
    this.cancellation,
  }) {
    if (pluginId.trim().isEmpty) {
      throw ArgumentError.value(pluginId, 'pluginId', 'Tidak boleh kosong.');
    }
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Tidak boleh kosong.',
      );
    }
  }

  final String pluginId;
  final String operationId;
  final String? stepId;
  final SandboxConfig config;
  final CancellationToken? cancellation;

  bool get isCancelled => cancellation?.isCancelled ?? false;

  PermissionGuard get permissionGuard => PermissionGuard(config.permissions);

  /// Melempar error permission terstruktur bila izin tidak aktif.
  void requirePermission(PluginPermission permission) {
    final denial = permissionGuard.denialFor(permission, pluginId: pluginId);
    if (denial != null) {
      throw denial;
    }
  }

  /// Melempar `operation.cancelled` bila token sudah dibatalkan.
  void ensureActive() {
    if (isCancelled) {
      throw const AppError(
        category: ErrorCategory.cancelled,
        code: 'operation.cancelled',
        message: 'Eksekusi dibatalkan.',
      );
    }
  }
}

/// Kontrak runtime yang dijalankan di dalam sandbox.
///
/// Implementasi DSL, Lua, dan WASM wajib memeriksa [SandboxContext] sebelum
/// melakukan side effect. Timeout dan pembatalan ditegakkan oleh host isolate
/// saat tersedia (F05).
abstract interface class SandboxRuntime {
  Future<Buffer> execute(
    Buffer input,
    Map<String, Object?> args,
    SandboxContext context,
  );
}

/// Runtime yang memegang resource native/isolate dan harus dilepas saat cache
/// mengeluarkannya (idle, LRU, plugin nonaktif/dihapus).
abstract interface class DisposableSandboxRuntime {
  Future<void> dispose();
}
