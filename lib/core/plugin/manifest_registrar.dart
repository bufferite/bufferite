import '../error/app_error.dart';
import 'operation.dart';
import 'operation_registry.dart';
import 'plugin_manifest.dart';

/// Memetakan operasi manifest ke [OperationRegistry].
final class ManifestRegistrar {
  const ManifestRegistrar(this.registry);

  final OperationRegistry registry;

  /// Mendaftarkan semua operasi manifest.
  ///
  /// [supportedTiers] menentukan tier yang siap dijalankan. Operasi dari tier
  /// yang belum didukung tetap didaftarkan sebagai `available=false` agar UI
  /// dapat menampilkan status unsupported. Error duplikat ID dikembalikan
  /// sebagai daftar tanpa menghentikan operasi lain.
  List<AppError> register(
    PluginManifest manifest, {
    Set<RuntimeTier> supportedTiers = const <RuntimeTier>{
      RuntimeTier.dsl,
      RuntimeTier.lua,
      RuntimeTier.wasm,
    },
    bool enabled = true,
    Operation? Function(String operationId)? executorFor,
  }) {
    final errors = <AppError>[];
    final available = enabled && supportedTiers.contains(manifest.tier);

    for (final descriptor in manifest.toOperationDescriptors(
      available: available,
    )) {
      final result = registry.register(
        descriptor,
        executor: executorFor?.call(descriptor.id),
      );
      final error = result.errorOrNull;
      if (error != null) {
        errors.add(error);
      }
    }
    return List<AppError>.unmodifiable(errors);
  }
}
