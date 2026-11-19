import 'package:flutter/material.dart';

import '../design_tokens.dart';
import 'app_badge.dart';

enum StepCardState { normal, disabled, error, unsupported }

/// Kartu step operasi sesuai `DESIGN.md` §6.2.
///
/// Fokus komponen ini adalah tampilan dan interaksi dasar; drag-and-drop
/// reorder ditangani di Recipe Editor (F09).
class StepCard extends StatelessWidget {
  const StepCard({
    super.key,
    required this.name,
    required this.category,
    this.state = StepCardState.normal,
    this.enabled = true,
    this.tier,
    this.errorMessage,
    this.onEnabledChanged,
    this.onTap,
    this.onDelete,
  });

  final String name;
  final String category;
  final StepCardState state;
  final bool enabled;

  /// Label tier runtime (dsl/lua/wasm), mis. ditampilkan sebagai badge.
  final String? tier;
  final String? errorMessage;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  bool get _isDisabled => state == StepCardState.disabled || !enabled;
  bool get _isUnsupported => state == StepCardState.unsupported;
  bool get _isError => state == StepCardState.error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final borderColor = _isError
        ? palette.danger
        : theme.colorScheme.outlineVariant;

    final card = Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: _isUnsupported ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Opacity(
          opacity: _isDisabled ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Icon(Icons.drag_indicator, size: 20, color: palette.textMuted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _isDisabled
                              ? palette.textMuted
                              : palette.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            category,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                          if (tier != null) AppBadge(label: tier!),
                          if (_isUnsupported)
                            const AppBadge(
                              label: 'unsupported',
                              tone: AppBadgeTone.warning,
                            ),
                        ],
                      ),
                      if (_isError && errorMessage != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: palette.danger,
                            ),
                            const SizedBox(width: AppSpacing.xs),
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
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (onEnabledChanged != null)
                  Switch(
                    value: enabled,
                    onChanged: _isUnsupported ? null : onEnabledChanged,
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Hapus step',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                if (onTap != null)
                  IconButton(
                    tooltip: 'Atur step',
                    onPressed: _isUnsupported ? null : onTap,
                    icon: const Icon(Icons.chevron_right, size: 24),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      enabled: !_isDisabled,
      button: onTap != null,
      label: '$name, $category',
      child: card,
    );
  }
}
