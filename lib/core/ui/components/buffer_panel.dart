import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/app_localizations.dart';
import '../design_tokens.dart';

/// Panel buffer input/output sesuai `DESIGN.md` §6.3.
class BufferPanel extends StatelessWidget {
  const BufferPanel({
    super.key,
    required this.label,
    this.kind = 'text',
    this.content,
    this.live = false,
    this.expanded = false,
    this.errorMessage,
    this.emptyHint,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onExpand,
  });

  final String label;
  final String kind;
  final String? content;
  final bool live;
  final bool expanded;
  final String? errorMessage;
  final String? emptyHint;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final text = content;
    final isEmpty = text == null || text.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _header(context, palette, isEmpty),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: isEmpty ? _empty(context, palette) : _body(theme, text),
              ),
            ],
          ),
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: palette.danger),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.error_outline, size: 18, color: palette.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context, AppPalette palette, bool isEmpty) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            kind,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
          if (live) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.circle, size: 8, color: palette.success),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'live',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.success,
              ),
            ),
          ],
          const Spacer(),
          if (!isEmpty)
            IconButton(
              tooltip: context.tr('common.copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content ?? ''));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text(context.tr('common.copied'))),
                );
              },
              icon: const Icon(Icons.copy, size: 20),
            ),
          if (onExpand != null)
            IconButton(
              tooltip: expanded
                  ? context.tr('common.collapse')
                  : context.tr('common.expand'),
              onPressed: onExpand,
              icon: Icon(
                expanded ? Icons.close_fullscreen : Icons.open_in_full,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(ThemeData theme, String text) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: expanded ? 400 : 180),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'Roboto Mono',
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            fontSize: 14,
            height: 20 / 14,
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, AppPalette palette) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            emptyHint ?? context.tr('common.noData'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ),
        if (emptyActionLabel != null && onEmptyAction != null)
          TextButton(onPressed: onEmptyAction, child: Text(emptyActionLabel!)),
      ],
    );
  }
}
