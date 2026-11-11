import 'operation_registry.dart';

/// Operasi siklus hidup plugin terhadap registry.
///
/// Service ini tidak menyentuh penyimpanan; orkestrasi persistensi dan
/// bootstrap ada di `PluginManagerService` (F04-T10).
final class PluginLifecycleService {
  const PluginLifecycleService({
    required this.registry,
    this.corePluginId = 'dev.bufferite.core',
  });

  final OperationRegistry registry;
  final String corePluginId;

  /// Mengaktifkan plugin dan mengembalikan peringatan (jika ada).
  List<String> enable(String pluginId) {
    registry.setPluginAvailability(pluginId, available: true);
    return const <String>[];
  }

  /// Menonaktifkan plugin sehingga operasinya hilang dari picker.
  List<String> disable(String pluginId) {
    registry.setPluginAvailability(pluginId, available: false);
    if (pluginId == corePluginId) {
      return const <String>[
        'Plugin core dinonaktifkan; operasi dasar tidak akan tersedia.',
      ];
    }
    return const <String>[];
  }

  /// Menghapus semua operasi plugin dari registry.
  List<String> remove(String pluginId) {
    registry.unregisterByPlugin(pluginId);
    if (pluginId == corePluginId) {
      return const <String>[
        'Plugin core dihapus; operasi dasar tidak akan tersedia.',
      ];
    }
    return const <String>[];
  }
}
