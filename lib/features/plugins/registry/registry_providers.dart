import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/plugin/installed_plugin.dart';
import '../../../core/registry/registry_cache.dart';
import '../../../core/registry/registry_cache_store.dart';
import '../../../core/registry/registry_client.dart';
import '../../../core/registry/registry_error.dart';
import '../../../core/registry/registry_index.dart';
import '../../../core/registry/registry_installer.dart';
import '../../../core/registry/registry_plugin_status.dart';
import '../../../core/registry/registry_signature.dart';
import '../../../core/registry/registry_transport.dart';
import '../../../core/storage/storage_providers.dart';
import '../../operations/operation_providers.dart';
import '../../settings/settings_provider.dart';
import '../plugin_manager_service.dart';
import '../plugin_providers.dart';

/// Aset trust store publik; dipin di aplikasi sesuai D13.
const String registryTrustStoreAsset = 'assets/registry_keys.json';

/// Cache indeks registry di application support.
final registryCacheStoreProvider = Provider<RegistryCacheStore>(
  (ref) => FileRegistryCacheStore(),
);

/// Transport HTTPS bersama untuk indeks, signature, dan paket.
final registryTransportProvider = Provider<RegistryTransport>((ref) {
  final transport = IoRegistryTransport();
  ref.onDispose(transport.close);
  return transport;
});

/// Public key Ed25519 yang di-pin di aplikasi.
final registryTrustStoreProvider = FutureProvider<RegistryTrustStore>((
  ref,
) async {
  final String source;
  try {
    source = await rootBundle.loadString(registryTrustStoreAsset);
  } on FlutterError catch (error) {
    throw RegistryClientException(
      'registry.trust_store_missing',
      'Trust anchor registry belum tersedia: $error',
    );
  }
  return RegistryTrustStore.fromBytes(utf8.encode(source));
});

final registryClientProvider = FutureProvider<RegistryClient>((ref) async {
  final trustStore = await ref.watch(registryTrustStoreProvider.future);
  return RegistryClient(
    trustStore: trustStore,
    transport: ref.watch(registryTransportProvider),
    cacheStore: ref.watch(registryCacheStoreProvider),
    userAgent: _userAgent(ref),
  );
});

final registryInstallerProvider = FutureProvider<RegistryInstaller>((
  ref,
) async {
  final trustStore = await ref.watch(registryTrustStoreProvider.future);
  return RegistryInstaller(
    transport: ref.watch(registryTransportProvider),
    trustStore: trustStore,
    userAgent: _userAgent(ref),
  );
});

/// Snapshot katalog terverifikasi; `null` berarti cache belum ada.
class RegistryCatalogController extends AsyncNotifier<RegistrySnapshot?> {
  @override
  Future<RegistrySnapshot?> build() async {
    final client = await ref.watch(registryClientProvider.future);
    final snapshot = await client.loadCached();
    if (snapshot != null) {
      await _applyRevocations(snapshot);
    }
    return snapshot;
  }

  /// Refresh jaringan. Wajib ada konsen; cache tetap dipakai bila offline.
  Future<void> refresh() async {
    final settings = await ref.read(settingsProvider.future);
    if (!settings.registryConsent) {
      throw const RegistryClientException(
        'registry.consent_required',
        'Akses jaringan katalog belum diizinkan.',
      );
    }

    state = await AsyncValue.guard<RegistrySnapshot?>(() async {
      final client = await ref.read(registryClientProvider.future);
      final snapshot = await client.loadWithFallback();
      await _applyRevocations(snapshot);
      return snapshot;
    });
  }

  /// Hapus cache lokal tanpa menyentuh plugin terpasang.
  Future<void> clearCache() async {
    await ref.read(registryCacheStoreProvider).clear();
    state = const AsyncData<RegistrySnapshot?>(null);
  }

  /// Nonaktifkan plugin terpasang yang rilisnya berstatus `revoked`.
  ///
  /// Kegagalan di sini tidak boleh membuat katalog gagal dimuat; badge status
  /// tetap ditampilkan oleh [registryPluginStatusesProvider].
  Future<void> _applyRevocations(RegistrySnapshot snapshot) async {
    try {
      final installed = await ref.read(pluginRepositoryProvider).list();
      var changed = false;
      for (final plugin in installed) {
        final status = registryStatusFor(
          pluginId: plugin.pluginId,
          installedVersion: plugin.version,
          index: snapshot.index,
          appVersion: ref.read(appVersionProvider),
        );
        if (plugin.enabled && status?.isRevoked == true) {
          await ref
              .read(pluginManagerServiceProvider)
              .setEnabled(plugin.pluginId, false);
          changed = true;
        }
      }
      if (changed) {
        ref.invalidate(installedPluginsProvider);
        ref.read(operationsRevisionProvider.notifier).bump();
      }
    } on Object {
      // Status revocation tetap terlihat di UI; enforcement dicoba lagi saat
      // refresh berikutnya.
    }
  }
}

final registryCatalogProvider =
    AsyncNotifierProvider<RegistryCatalogController, RegistrySnapshot?>(
      RegistryCatalogController.new,
    );

/// Status update/revocation plugin terpasang berdasarkan katalog terakhir.
///
/// Kosong bila katalog belum dimuat atau trust anchor belum tersedia; UI tidak
/// menampilkan badge apa pun dalam kondisi itu.
final registryPluginStatusesProvider =
    Provider<Map<String, PluginRegistryStatus>>((ref) {
      final snapshot = ref.watch(registryCatalogProvider).asData?.value;
      final installed = ref.watch(installedPluginsProvider).asData?.value;
      if (snapshot == null || installed == null) {
        return const <String, PluginRegistryStatus>{};
      }
      final appVersion = ref.watch(appVersionProvider);
      final statuses = <String, PluginRegistryStatus>{};
      for (final plugin in installed) {
        final status = registryStatusFor(
          pluginId: plugin.pluginId,
          installedVersion: plugin.version,
          index: snapshot.index,
          appVersion: appVersion,
        );
        if (status != null) {
          statuses[plugin.pluginId] = status;
        }
      }
      return statuses;
    });

/// Memasang entri registry setelah unduhan + signature diverifikasi.
class RegistryInstallService {
  RegistryInstallService(this._ref);

  final Ref _ref;

  Future<InstalledPlugin> install({
    required RegistryEntry entry,
    required RegistrySnapshot snapshot,
  }) async {
    final installer = await _ref.read(registryInstallerProvider.future);
    final existing = await _ref
        .read(pluginRepositoryProvider)
        .byId(entry.pluginId);
    final verified = await installer.downloadAndVerify(
      entry: entry,
      index: snapshot.index,
      indexSourceUrl: snapshot.sourceUrl,
    );

    final sameVersion = existing != null && existing.version == entry.version;
    final previous = existing?.provenance;
    final provenance = PluginProvenance(
      registryUrl: snapshot.sourceUrl.toString(),
      keyId: verified.keyId,
      sha256: verified.sha256,
      previousVersion: sameVersion
          ? previous?.previousVersion
          : existing?.version.toString(),
      previousSource: sameVersion ? previous?.previousSource : existing?.source,
      previousVerified: sameVersion
          ? previous?.previousVerified
          : existing?.verified,
    );

    final plugin = await _ref
        .read(pluginManagerServiceProvider)
        .update(
          verified.package,
          source: PluginSource.registry,
          verified: true,
          provenance: provenance,
        );

    _ref.invalidate(installedPluginsProvider);
    _ref.read(operationsRevisionProvider.notifier).bump();
    return plugin;
  }
}

final registryInstallServiceProvider = Provider<RegistryInstallService>(
  (ref) => RegistryInstallService(ref),
);

String _userAgent(Ref ref) {
  final version = ref.watch(appVersionProvider);
  return 'Bufferite/$version';
}
