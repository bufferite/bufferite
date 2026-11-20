import '../plugin/semantic_version.dart';
import 'registry_index.dart';

/// Status registry untuk satu plugin terpasang.
///
/// [update] hanya berisi rilis `active` yang lebih baru dan memenuhi
/// `minAppVersion`; status lain mengikuti rilis yang sedang terpasang.
final class PluginRegistryStatus {
  const PluginRegistryStatus({
    required this.installedVersion,
    this.installedRelease,
    this.latestRelease,
    this.update,
  });

  final SemanticVersion installedVersion;
  final RegistryEntry? installedRelease;
  final RegistryEntry? latestRelease;
  final RegistryEntry? update;

  bool get hasUpdate => update != null;

  RegistryEntryStatus? get installedStatus => installedRelease?.status;

  bool get isRevoked => installedStatus == RegistryEntryStatus.revoked;

  bool get isYanked => installedStatus == RegistryEntryStatus.yanked;

  bool get isDeprecated => installedStatus == RegistryEntryStatus.deprecated;
}

/// Hitung status registry untuk plugin yang sedang terpasang.
///
/// Mengembalikan `null` bila plugin tidak ada di indeks.
PluginRegistryStatus? registryStatusFor({
  required String pluginId,
  required SemanticVersion installedVersion,
  required RegistryIndex index,
  required SemanticVersion appVersion,
}) {
  RegistryEntry? installedRelease;
  RegistryEntry? latestRelease;
  RegistryEntry? update;

  for (final entry in index.plugins) {
    if (entry.pluginId != pluginId) {
      continue;
    }
    if (entry.version == installedVersion) {
      installedRelease = entry;
    }
    if (latestRelease == null ||
        entry.version.compareTo(latestRelease.version) > 0) {
      latestRelease = entry;
    }
    if (entry.status == RegistryEntryStatus.active &&
        entry.version.compareTo(installedVersion) > 0 &&
        appVersion.isAtLeast(entry.minAppVersion) &&
        (update == null || entry.version.compareTo(update.version) > 0)) {
      update = entry;
    }
  }

  if (latestRelease == null && installedRelease == null) {
    return null;
  }
  return PluginRegistryStatus(
    installedVersion: installedVersion,
    installedRelease: installedRelease,
    latestRelease: latestRelease,
    update: update,
  );
}

/// Semua rilis [pluginId] di indeks, terbaru lebih dulu.
List<RegistryEntry> registryReleasesFor(RegistryIndex index, String pluginId) {
  return index.plugins.where((entry) => entry.pluginId == pluginId).toList()
    ..sort((a, b) => b.version.compareTo(a.version));
}
