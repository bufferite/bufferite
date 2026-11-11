import 'package:flutter/material.dart';

import '../design_tokens.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

/// Tombol sesuai `DESIGN.md` §6.1.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? _paletteDark
        : _paletteLight;
    final effective = loading ? null : onPressed;
    final child = _child(theme);

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        onPressed: effective,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: Colors.white,
        ),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effective,
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.surfaceAlt,
          foregroundColor: palette.textPrimary,
        ),
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: effective,
        style: TextButton.styleFrom(foregroundColor: palette.textSecondary),
        child: child,
      ),
      AppButtonVariant.danger => ElevatedButton(
        onPressed: effective,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.danger,
          foregroundColor: Colors.white,
        ),
        child: child,
      ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _child(ThemeData theme) {
    final text = Text(label);
    if (loading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          text,
        ],
      );
    }
    if (icon == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        text,
      ],
    );
  }
}

/// Palet dibaca langsung agar komponen tetap benar walau diuji tanpa tema
/// kustom. Nilai diselaraskan dengan `AppPalette`.
const _paletteLight = (
  accent: Color(0xFF2563EB),
  surfaceAlt: Color(0xFFF4F4F5),
  textPrimary: Color(0xFF09090B),
  textSecondary: Color(0xFF52525B),
  danger: Color(0xFFDC2626),
);
const _paletteDark = (
  accent: Color(0xFF3B82F6),
  surfaceAlt: Color(0xFF18181B),
  textPrimary: Color(0xFFFAFAFA),
  textSecondary: Color(0xFFA1A1AA),
  danger: Color(0xFFEF4444),
);
