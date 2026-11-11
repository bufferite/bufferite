import '../engine/buffer.dart';
import '../error/app_error.dart';
import 'operation_param.dart';

const int operationContractVersion = 1;

enum OperationCategory {
  encodeDecode('Encode/Decode'),
  crypto('Crypto'),
  format('Format'),
  analysis('Analysis'),
  utility('Utility');

  const OperationCategory(this.label);

  final String label;

  static OperationCategory parse(Object? value) {
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      for (final category in values) {
        if (category.name.toLowerCase() == normalized ||
            category.label.toLowerCase() == normalized) {
          return category;
        }
      }
    }
    throw AppError(
      category: ErrorCategory.validation,
      code: 'operation.category_invalid',
      message: 'Kategori operasi tidak dikenal: $value',
    );
  }
}

enum RuntimeTier {
  dsl,
  lua,
  wasm;

  static RuntimeTier parse(Object? value) {
    if (value is String) {
      for (final tier in values) {
        if (tier.name == value) {
          return tier;
        }
      }
    }
    throw AppError(
      category: ErrorCategory.validation,
      code: 'plugin.tier_invalid',
      message: 'Tier runtime tidak dikenal: $value',
    );
  }
}

final class OperationIO {
  const OperationIO({required this.input, required this.output});

  final BufferKind input;
  final BufferKind output;

  factory OperationIO.fromJson(Map<String, Object?> json) {
    return OperationIO(
      input: BufferKind.parse(json['input']),
      output: BufferKind.parse(json['output']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'input': input.name, 'output': output.name};
  }
}

/// Kontrak yang diimplementasikan semua operasi, baik core maupun plugin.
///
/// Argumen yang diterima [execute] sudah melewati default dan validasi
/// (lihat `resolveOperationArgs`). Implementasi tidak boleh memutasi [input].
abstract interface class Operation {
  String get id;

  String get name;

  OperationCategory get category;

  List<OperationParam> get params;

  OperationIO get io;

  Future<Buffer> execute(Buffer input, Map<String, Object?> args);
}

/// Metadata operasi yang bisa didaftarkan sebelum runtime siap.
final class OperationDescriptor {
  OperationDescriptor({
    required this.id,
    required this.name,
    required this.category,
    required this.pluginId,
    required this.pluginVersion,
    required this.tier,
    required List<OperationParam> params,
    required this.io,
    this.contractVersion = operationContractVersion,
    this.available = true,
  }) : params = List<OperationParam>.unmodifiable(params);

  factory OperationDescriptor.fromOperation(
    Operation operation, {
    required String pluginId,
    required String pluginVersion,
    required RuntimeTier tier,
    int contractVersion = operationContractVersion,
    bool available = true,
  }) {
    return OperationDescriptor(
      id: operation.id,
      name: operation.name,
      category: operation.category,
      pluginId: pluginId,
      pluginVersion: pluginVersion,
      tier: tier,
      params: operation.params,
      io: operation.io,
      contractVersion: contractVersion,
      available: available,
    );
  }

  final String id;
  final String name;
  final OperationCategory category;
  final String pluginId;
  final String pluginVersion;
  final RuntimeTier tier;
  final List<OperationParam> params;
  final OperationIO io;
  final int contractVersion;

  /// False bila plugin nonaktif, runtime tidak tersedia, atau operasi gagal
  /// dimuat. Descriptor tetap disimpan agar UI bisa menampilkan status.
  final bool available;

  bool get isContractSupported => contractVersion <= operationContractVersion;

  bool get isSupported => available && isContractSupported;

  OperationDescriptor copyWith({bool? available}) {
    return OperationDescriptor(
      id: id,
      name: name,
      category: category,
      pluginId: pluginId,
      pluginVersion: pluginVersion,
      tier: tier,
      params: params,
      io: io,
      contractVersion: contractVersion,
      available: available ?? this.available,
    );
  }
}
