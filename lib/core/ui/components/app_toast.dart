import 'dart:async';

import 'package:flutter/material.dart';

import '../design_tokens.dart';

enum AppToastTone { info, success, warning, error }

/// Generasi toast terakhir; dipakai agar timer toast lama tidak menghapus
/// toast baru.
int _toastGeneration = 0;

/// Menampilkan snackbar sesuai `DESIGN.md` §6.7.
///
/// Warna semantik hanya dipakai pada ikon, bukan seluruh background. Aksi
/// `undoLabel` dipakai untuk aksi destruktif.
///
/// Toast sebelumnya langsung dibuang supaya tidak menumpuk. Saat mode
/// aksesibilitas aktif, SnackBar Flutter tidak menutup sendiri sehingga toast
/// dipaksa hilang setelah [duration].
void showAppToast(
  BuildContext context, {
  required String message,
  AppToastTone tone = AppToastTone.info,
  String? undoLabel,
  VoidCallback? onUndo,
  Duration duration = const Duration(seconds: 3),
}) {
  final palette = Theme.of(context).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
  final (icon, color) = _toneStyle(tone, palette);
  final messenger = ScaffoldMessenger.of(context);

  messenger
    ..hideCurrentSnackBar()
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        // Flutter 3.44 membuat SnackBar beraksi persisten secara default; toast
        // harus tetap hilang sendiri.
        persist: false,
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

  if (MediaQuery.accessibleNavigationOf(context)) {
    final generation = ++_toastGeneration;
    unawaited(
      Future<void>.delayed(duration + const Duration(milliseconds: 400), () {
        if (generation == _toastGeneration) {
          messenger.hideCurrentSnackBar();
        }
      }),
    );
  }
}

(IconData, Color) _toneStyle(AppToastTone tone, AppPalette palette) {
  return switch (tone) {
    AppToastTone.info => (Icons.info_outline, palette.accent),
    AppToastTone.success => (Icons.check_circle_outline, palette.success),
    AppToastTone.warning => (Icons.warning_amber_rounded, palette.warning),
    AppToastTone.error => (Icons.error_outline, palette.danger),
  };
}
