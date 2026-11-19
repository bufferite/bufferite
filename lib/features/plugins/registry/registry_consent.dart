import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../settings/settings_provider.dart';

/// Dialog konsen akses jaringan katalog (REGISTRY.md §6).
Future<bool> showRegistryConsentDialog(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('registry.consentTitle')),
      content: Text(context.tr('registry.consentBody')),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.tr('registry.consentAccept')),
        ),
      ],
    ),
  );
  return accepted ?? false;
}

/// Memastikan konsen sudah ada; menyimpan persetujuan bila baru diberikan.
Future<bool> ensureRegistryConsent(BuildContext context, WidgetRef ref) async {
  final current = await ref.read(settingsProvider.future);
  if (current.registryConsent) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final accepted = await showRegistryConsentDialog(context);
  if (!accepted) {
    return false;
  }
  await ref.read(settingsProvider.notifier).setRegistryConsent(true);
  return true;
}
