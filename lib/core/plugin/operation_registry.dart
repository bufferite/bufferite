import '../error/app_error.dart';
import '../error/result.dart';
import 'operation.dart';

final class RegisteredOperation {
  const RegisteredOperation({required this.descriptor, this.executor});

  final OperationDescriptor descriptor;

  /// Null bila operasi belum/tidak dapat dieksekusi (mis. runtime mati).
  final Operation? executor;
}

/// Registry operasi in-memory.
///
/// Registry tidak menyentuh storage. Pemanggil bertanggung jawab memuat
/// manifest/plugin dan mendaftarkan descriptor yang sudah divalidasi.
final class OperationRegistry {
  final Map<String, RegisteredOperation> _entries =
      <String, RegisteredOperation>{};
  final List<String> _warnings = <String>[];

  List<String> get warnings => List<String>.unmodifiable(_warnings);

  int get count => _entries.length;

  /// Daftarkan operasi. ID duplikat ditolak dan descriptor pertama
  /// dipertahankan sesuai `operations.md`.
  Result<RegisteredOperation> register(
    OperationDescriptor descriptor, {
    Operation? executor,
  }) {
    final existing = _entries[descriptor.id];
    if (existing != null) {
      final error = AppError(
        category: ErrorCategory.plugin,
        code: 'operation.duplicate_id',
        message: 'Operasi ${descriptor.id} sudah terdaftar.',
        pluginId: descriptor.pluginId,
        details: <String, Object?>{
          'operationId': descriptor.id,
          'existingPluginId': existing.descriptor.pluginId,
        },
      );
      _warnings.add(error.message);
      return Err<RegisteredOperation>(error);
    }

    final entry = RegisteredOperation(
      descriptor: descriptor,
      executor: executor,
    );
    _entries[descriptor.id] = entry;
    return Ok<RegisteredOperation>(entry);
  }

  Result<RegisteredOperation> registerOperation(
    Operation operation, {
    required String pluginId,
    required String pluginVersion,
    required RuntimeTier tier,
    int contractVersion = operationContractVersion,
    bool available = true,
  }) {
    return register(
      OperationDescriptor.fromOperation(
        operation,
        pluginId: pluginId,
        pluginVersion: pluginVersion,
        tier: tier,
        contractVersion: contractVersion,
        available: available,
      ),
      executor: operation,
    );
  }

  bool contains(String id) => _entries.containsKey(id);

  RegisteredOperation? byId(String id) => _entries[id];

  List<RegisteredOperation> all({bool includeUnsupported = false}) {
    return _filtered(_entries.values, includeUnsupported);
  }

  List<RegisteredOperation> byCategory(
    OperationCategory category, {
    bool includeUnsupported = false,
  }) {
    return _filtered(
      _entries.values.where((entry) => entry.descriptor.category == category),
      includeUnsupported,
    );
  }

  List<RegisteredOperation> byPlugin(String pluginId) {
    return List<RegisteredOperation>.unmodifiable(
      _entries.values.where((entry) => entry.descriptor.pluginId == pluginId),
    );
  }

  List<RegisteredOperation> search(
    String query, {
    bool includeUnsupported = false,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return all(includeUnsupported: includeUnsupported);
    }
    return _filtered(
      _entries.values.where((entry) {
        final descriptor = entry.descriptor;
        return descriptor.id.toLowerCase().contains(normalized) ||
            descriptor.name.toLowerCase().contains(normalized) ||
            descriptor.category.label.toLowerCase().contains(normalized) ||
            descriptor.pluginId.toLowerCase().contains(normalized);
      }),
      includeUnsupported,
    );
  }

  /// Ambil operasi yang siap dieksekusi. Error `unsupported` dipakai engine
  /// untuk melewati step dengan peringatan, bukan crash.
  Result<RegisteredOperation> require(String id) {
    final entry = _entries[id];
    if (entry == null) {
      return Err<RegisteredOperation>(
        AppError(
          category: ErrorCategory.unsupported,
          code: 'operation.not_found',
          message: 'Operasi $id tidak ditemukan.',
          details: <String, Object?>{'operationId': id},
        ),
      );
    }
    if (!entry.descriptor.isSupported) {
      return Err<RegisteredOperation>(
        AppError(
          category: ErrorCategory.unsupported,
          code: 'operation.unsupported',
          message: 'Operasi $id tidak tersedia.',
          pluginId: entry.descriptor.pluginId,
          details: <String, Object?>{
            'operationId': id,
            'available': entry.descriptor.available,
            'contractVersion': entry.descriptor.contractVersion,
            'supportedContractVersion': operationContractVersion,
          },
        ),
      );
    }
    if (entry.executor == null) {
      return Err<RegisteredOperation>(
        AppError(
          category: ErrorCategory.unsupported,
          code: 'operation.unsupported',
          message: 'Runtime operasi $id belum siap.',
          pluginId: entry.descriptor.pluginId,
          details: <String, Object?>{'operationId': id},
        ),
      );
    }
    return Ok<RegisteredOperation>(entry);
  }

  bool unregister(String id) => _entries.remove(id) != null;

  int unregisterByPlugin(String pluginId) {
    final ids = _entries.values
        .where((entry) => entry.descriptor.pluginId == pluginId)
        .map((entry) => entry.descriptor.id)
        .toList();
    for (final id in ids) {
      _entries.remove(id);
    }
    return ids.length;
  }

  int setPluginAvailability(String pluginId, {required bool available}) {
    final ids = _entries.values
        .where((entry) => entry.descriptor.pluginId == pluginId)
        .map((entry) => entry.descriptor.id)
        .toList();
    for (final id in ids) {
      final entry = _entries[id]!;
      _entries[id] = RegisteredOperation(
        descriptor: entry.descriptor.copyWith(available: available),
        executor: entry.executor,
      );
    }
    return ids.length;
  }

  void clear() {
    _entries.clear();
    _warnings.clear();
  }

  List<RegisteredOperation> _filtered(
    Iterable<RegisteredOperation> entries,
    bool includeUnsupported,
  ) {
    final result = includeUnsupported
        ? entries.toList()
        : entries.where((entry) => entry.descriptor.isSupported).toList();
    return List<RegisteredOperation>.unmodifiable(result);
  }
}
