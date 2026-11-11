import 'package:flutter/material.dart';

/// Token warna sesuai `DESIGN.md` §2.
@immutable
final class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
  });

  static const AppPalette light = AppPalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFAFAFA),
    surfaceAlt: Color(0xFFF4F4F5),
    border: Color(0xFFE4E4E7),
    borderStrong: Color(0xFFD4D4D8),
    textPrimary: Color(0xFF09090B),
    textSecondary: Color(0xFF52525B),
    textMuted: Color(0xFFA1A1AA),
    accent: Color(0xFF2563EB),
    accentHover: Color(0xFF1D4ED8),
    accentSoft: Color(0xFFEFF6FF),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF09090B),
    surface: Color(0xFF121214),
    surfaceAlt: Color(0xFF18181B),
    border: Color(0xFF27272A),
    borderStrong: Color(0xFF3F3F46),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    accent: Color(0xFF3B82F6),
    accentHover: Color(0xFF60A5FA),
    accentSoft: Color(0xFF172554),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
  );

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;

  ColorScheme toColorScheme(Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: background,
      onSurface: textPrimary,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surfaceAlt,
      onSurfaceVariant: textSecondary,
      outline: borderStrong,
      outlineVariant: border,
      primaryContainer: accentSoft,
      onPrimaryContainer: textPrimary,
    );
  }
}

/// Spacing scale `DESIGN.md` §4.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Radius `DESIGN.md` §4.
abstract final class AppRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double pill = 999;
}

/// Ukuran target sentuh minimum `DESIGN.md` §1.
const double appMinTouchTarget = 44;
