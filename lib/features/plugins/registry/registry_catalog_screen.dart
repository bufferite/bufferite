import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/plugin/installed_plugin.dart';
import '../../../core/registry/registry_client.dart';
import '../../../core/registry/registry_index.dart';
import '../../../core/registry/registry_plugin_status.dart';
import '../../../core/ui/components/app_badge.dart';
import '../../../core/ui/components/empty_state.dart';
import '../../../core/ui/design_tokens.dart';
import '../../settings/settings_provider.dart';
import '../plugin_providers.dart';
import 'registry_consent.dart';
import 'registry_detail_screen.dart';
import 'registry_error_text.dart';
import 'registry_providers.dart';

/// Katalog registry resmi read-only (F16-T02).
class RegistryCatalogScreen extends ConsumerStatefulWidget {
  const RegistryCatalogScreen({super.key});

  @override
  ConsumerState<RegistryCatalogScreen> createState() =>
      _RegistryCatalogScreenState();
}

class _RegistryCatalogScreenState extends ConsumerState<RegistryCatalogScreen> {
  bool _consentScheduled = false;
  bool _consentOpen = false;
  bool _consentPrompted = false;
  bool _refreshing = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).asData?.value;
    final consent = settings?.registryConsent ?? false;
    final catalog = ref.watch(registryCatalogProvider);

    ref.listen(settingsProvider, (previous, next) {
      if (next.asData?.value.registryConsent == false) {
        _scheduleConsentPrompt();
      }
    });
    if (settings != null && !consent) {
      _scheduleConsentPrompt();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('registry.catalogTitle')),
        actions: <Widget>[
          IconButton(
            tooltip: context.tr('registry.refresh'),
            onPressed: consent && !_refreshing ? _refresh : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (catalog.isLoading || _refreshing) const LinearProgressIndicator(),
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => EmptyState(
                icon: Icons.cloud_off_outlined,
                title: context.tr('registry.loadFailed'),
                description: registryErrorText(context, error),
                actionLabel: consent ? context.tr('registry.refresh') : null,
                onAction: consent ? _refresh : null,
              ),
              data: (snapshot) => _content(snapshot, consent: consent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(RegistrySnapshot? snapshot, {required bool consent}) {
    if (snapshot == null) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: context.tr('registry.notLoadedTitle'),
        description: context.tr('registry.notLoadedDescription'),
        actionLabel: consent ? context.tr('registry.refresh') : null,
        onAction: consent ? _refresh : null,
      );
    }

    final installed = <String, InstalledPlugin>{
      for (final plugin
          in ref.watch(installedPluginsProvider).asData?.value ??
              const <InstalledPlugin>[])
        plugin.pluginId: plugin,
    };
    final registryStatuses = ref.watch(registryPluginStatusesProvider);
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final entries = _latestEntries(snapshot.index).where((entry) {
      if (_query.isEmpty) {
        return true;
      }
      final query = _query.toLowerCase();
      return entry.name.toLowerCase().contains(query) ||
          entry.pluginId.toLowerCase().contains(query) ||
          entry.summary.toLowerCase().contains(query) ||
          entry.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();

    return Column(
      children: <Widget>[
        if (!consent)
          _banner(
            message: context.tr('registry.consentRequiredBody'),
            icon: Icons.wifi_off,
            tone: palette.warning,
            actionLabel: context.tr('registry.consentAccept'),
            onAction: _requestConsent,
          ),
        if (snapshot.offline)
          _banner(
            message: context.tr('registry.offlineBanner'),
            icon: Icons.cloud_off,
            tone: palette.warning,
          )
        else if (snapshot.stale)
          _banner(
            message: context.tr('registry.staleBanner'),
            icon: Icons.schedule,
            tone: palette.warning,
          )
        else if (snapshot.fromCache)
          _banner(
            message: context.tr(
              'registry.cachedBanner',
              args: <String, Object?>{
                'date': _dateLabel(snapshot.fetchedAt.toLocal()),
              },
            ),
            icon: Icons.history,
            tone: palette.textSecondary,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: context.tr('registry.searchHint'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.tr(
                    'registry.sourceLine',
                    args: <String, Object?>{
                      'url': snapshot.sourceUrl.toString(),
                      'sequence': snapshot.index.sequence,
                    },
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                _dateLabel(snapshot.fetchedAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: entries.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: _query.isEmpty
                      ? context.tr('registry.emptyTitle')
                      : context.tr('registry.noResults'),
                  description: _query.isEmpty
                      ? context.tr('registry.emptyDescription')
                      : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _tile(
                    entries[index],
                    snapshot,
                    installed[entries[index].pluginId],
                    registryStatuses[entries[index].pluginId],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tile(
    RegistryEntry entry,
    RegistrySnapshot snapshot,
    InstalledPlugin? installed,
    PluginRegistryStatus? registryStatus,
  ) {
    final update = registryStatus?.update;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.extension_outlined)),
        title: Text(entry.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(entry.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${entry.pluginId} · v${entry.version}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                AppBadge(label: entry.tier.name),
                _statusBadge(entry.status),
                if (installed != null)
                  AppBadge(
                    label: context.tr(
                      'registry.installedVersion',
                      args: <String, Object?>{'version': installed.version},
                    ),
                    tone: AppBadgeTone.success,
                  ),
                if (registryStatus?.isRevoked == true)
                  AppBadge(
                    label: context.tr('registry.revokedBadge'),
                    tone: AppBadgeTone.danger,
                  )
                else if (update != null)
                  AppBadge(
                    label: context.tr(
                      'registry.updateBadge',
                      args: <String, Object?>{'version': update.version},
                    ),
                    tone: AppBadgeTone.accent,
                    icon: Icons.system_update,
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) =>
                RegistryDetailScreen(entry: entry, snapshot: snapshot),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(RegistryEntryStatus status) {
    return switch (status) {
      RegistryEntryStatus.active => AppBadge(
        label: context.tr('registry.status.active'),
        tone: AppBadgeTone.success,
      ),
      RegistryEntryStatus.deprecated => AppBadge(
        label: context.tr('registry.status.deprecated'),
        tone: AppBadgeTone.warning,
      ),
      RegistryEntryStatus.yanked => AppBadge(
        label: context.tr('registry.status.yanked'),
        tone: AppBadgeTone.warning,
      ),
      RegistryEntryStatus.revoked => AppBadge(
        label: context.tr('registry.status.revoked'),
        tone: AppBadgeTone.danger,
      ),
    };
  }

  Widget _banner({
    required String message,
    required IconData icon,
    required Color tone,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  void _scheduleConsentPrompt() {
    if (_consentScheduled || _consentOpen || _consentPrompted) {
      return;
    }
    _consentScheduled = true;
    _consentPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consentScheduled = false;
      if (mounted) {
        _requestConsent();
      }
    });
  }

  Future<void> _requestConsent() async {
    if (_consentOpen) {
      return;
    }
    _consentOpen = true;
    final accepted = await showRegistryConsentDialog(context);
    _consentOpen = false;
    if (!mounted || !accepted) {
      return;
    }
    await ref.read(settingsProvider.notifier).setRegistryConsent(true);
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    try {
      await ref.read(registryCatalogProvider.notifier).refresh();
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  List<RegistryEntry> _latestEntries(RegistryIndex index) {
    final latest = <String, RegistryEntry>{};
    for (final entry in index.plugins) {
      final current = latest[entry.pluginId];
      if (current == null || _preferEntry(entry, current)) {
        latest[entry.pluginId] = entry;
      }
    }
    final entries = latest.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return entries;
  }

  /// Rilis yang boleh dipasang menang atas rilis yanked/revoked; sesama
  /// kandidat diurutkan berdasarkan versi.
  bool _preferEntry(RegistryEntry candidate, RegistryEntry current) {
    if (candidate.status.selectable != current.status.selectable) {
      return candidate.status.selectable;
    }
    return candidate.version.compareTo(current.version) > 0;
  }

  String _dateLabel(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
