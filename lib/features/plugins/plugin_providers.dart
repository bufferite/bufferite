import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plugin/installed_plugin.dart';
import '../../core/plugin/semantic_version.dart';
import '../../core/storage/storage_providers.dart';

/// Versi aplikasi yang dipakai untuk cek kompatibilitas plugin.
final appVersionProvider = Provider<SemanticVersion>(
  (ref) => SemanticVersion.parse('1.0.0'),
);

/// Plugin terpasang dari SQLite.
final installedPluginsProvider = FutureProvider<List<InstalledPlugin>>(
  (ref) => ref.watch(pluginRepositoryProvider).list(),
);
