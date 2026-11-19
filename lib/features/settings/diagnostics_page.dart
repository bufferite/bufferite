import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/diagnostics_providers.dart';
import '../../core/diagnostics/execution_log.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/localized_error.dart';
import '../../core/ui/components/app_badge.dart';
import '../../core/ui/components/app_toast.dart';
import '../../core/ui/components/empty_state.dart';
import '../../core/ui/design_tokens.dart';
import '../settings/settings_provider.dart';

/// Layar diagnostik lokal: riwayat eksekusi pipeline saat opt-in aktif.
class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  List<ExecutionLogEntry>? _entries;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await ref.read(executionLogServiceProvider).recent();
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('diagnostics.clearTitle')),
        content: Text(context.tr('diagnostics.clearBody')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref.read(executionLogServiceProvider).clear();
      if (!mounted) {
        return;
      }
      await _load();
      if (mounted) {
        showAppToast(
          context,
          message: context.tr('diagnostics.cleared'),
          tone: AppToastTone.success,
        );
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: context.tr(
          'diagnostics.clearFailed',
          args: <String, Object?>{'error': context.trErrorObject(error)},
        ),
        tone: AppToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled =
        ref.watch(settingsProvider).asData?.value.optInLogging ?? false;
    final entries = _entries ?? const <ExecutionLogEntry>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('diagnostics.title')),
        actions: <Widget>[
          IconButton(
            tooltip: context.tr('diagnostics.refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: context.tr('diagnostics.clear'),
            onPressed: entries.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!enabled) ...<Widget>[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(context.tr('diagnostics.disabled')),
                      dense: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  context.tr('diagnostics.privacyNote'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body(theme, entries)),
        ],
      ),
    );
  }

  Widget _body(ThemeData theme, List<ExecutionLogEntry> entries) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: context.tr('diagnostics.loadFailed'),
        description: context.trErrorObject(_error!),
      );
    }
    if (entries.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: context.tr('diagnostics.emptyTitle'),
        description: context.tr('diagnostics.emptyBody'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: entries.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _entryCard(theme, entries[index]),
    );
  }

  Widget _entryCard(ThemeData theme, ExecutionLogEntry entry) {
    final palette = theme.brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final (icon, tone) = switch (entry.outcome) {
      ExecutionOutcome.success => (
        Icons.check_circle_outline,
        AppBadgeTone.success,
      ),
      ExecutionOutcome.failed => (Icons.error_outline, AppBadgeTone.danger),
      ExecutionOutcome.cancelled => (
        Icons.cancel_outlined,
        AppBadgeTone.warning,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: _toneColor(palette, tone)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    entry.recipeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: context.tr(
                    'diagnostics.outcome.${entry.outcome.name}',
                  ),
                  tone: tone,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_formatTimestamp(entry.timestamp)} · '
              '${entry.durationMs} ms',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            if (entry.operationIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                entry.operationIds.join(' → '),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'Roboto Mono',
                  color: palette.textMuted,
                ),
              ),
            ],
            if (entry.errorCodes.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.tr(
                  'diagnostics.errorCodes',
                  args: <String, Object?>{'codes': entry.errorCodes.join(', ')},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _toneColor(AppPalette palette, AppBadgeTone tone) {
    return switch (tone) {
      AppBadgeTone.success => palette.success,
      AppBadgeTone.danger => palette.danger,
      AppBadgeTone.warning => palette.warning,
      AppBadgeTone.accent => palette.accent,
      AppBadgeTone.neutral => palette.textSecondary,
    };
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
