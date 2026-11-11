import 'package:flutter/material.dart';

import '../design_tokens.dart';

enum AppToastTone { info, success, warning, error }

/// Menampilkan snackbar sesuai `DESIGN.md` §6.7.
///
/// Warna semantik hanya dipakai pada ikon, bukan seluruh background. Aksi
/// `undoLabel` dipakai untuk aksi destruktif.
void showAppToast(
  BuildContext context, {
  required String message,
  AppToastTone tone = AppToastTone.info,
  String? undoLabel,
  VoidCallback? onUndo,
}) {
  final palette = Theme.of(context).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
  final (icon, color) = _toneStyle(tone, palette);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      content: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
      action: undoLabel != null && onUndo != null
          ? SnackBarAction(label: undoLabel, onPressed: onUndo)
          : null,
    ),
  );
}

(IconData, Color) _toneStyle(AppToastTone tone, AppPalette palette) {
  return switch (tone) {
    AppToastTone.info => (Icons.info_outline, palette.accent),
    AppToastTone.success => (Icons.check_circle_outline, palette.success),
    AppToastTone.warning => (Icons.warning_amber_rounded, palette.warning),
    AppToastTone.error => (Icons.error_outline, palette.danger),
  };
}
