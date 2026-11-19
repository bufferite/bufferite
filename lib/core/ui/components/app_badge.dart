import 'package:flutter/material.dart';

import '../design_tokens.dart';

enum AppBadgeTone { neutral, accent, success, warning, danger }

/// Badge kecil untuk tier, status, dan label.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final color = switch (tone) {
      AppBadgeTone.neutral => palette.textSecondary,
      AppBadgeTone.accent => palette.accent,
      AppBadgeTone.success => palette.success,
      AppBadgeTone.warning => palette.warning,
      AppBadgeTone.danger => palette.danger,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
