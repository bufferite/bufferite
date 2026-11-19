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
import '../../../core/registry/registry_signature.dart';
import '../../../core/registry/registry_transport.dart';
import '../../../core/storage/storage_providers.dart';
import '../../operations/operation_providers.dart';
import '../../settings/settings_provider.dart';
import '../plugin_manager_service.dart';
import '../plugin_providers.dart';

/// Aset trust store publik; belum dibundel sampai D13 selesai.
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
    return client.loadCached();
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
      return client.loadWithFallback();
    });
  }

  /// Hapus cache lokal tanpa menyentuh plugin terpasang.
  Future<void> clearCache() async {
    await ref.read(registryCacheStoreProvider).clear();
    state = const AsyncData<RegistrySnapshot?>(null);
  }
}

final registryCatalogProvider =
    AsyncNotifierProvider<RegistryCatalogController, RegistrySnapshot?>(
      RegistryCatalogController.new,
    );

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

    final plugin = await _ref
        .read(pluginManagerServiceProvider)
        .install(
          verified.package,
          source: PluginSource.registry,
          verified: true,
          provenance: PluginProvenance(
            registryUrl: snapshot.sourceUrl.toString(),
            keyId: verified.keyId,
            sha256: verified.sha256,
            previousVersion: existing?.version.toString(),
          ),
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
