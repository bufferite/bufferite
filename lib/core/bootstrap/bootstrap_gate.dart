import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localizations.dart';
import '../i18n/localized_error.dart';
import '../ui/components/app_button.dart';
import '../ui/components/empty_state.dart';
import '../ui/design_tokens.dart';
import 'bootstrap_provider.dart';

/// Gate bootstrap: menampilkan error yang jelas bila `core.berp` gagal, tapi
/// tetap mengizinkan aplikasi dibuka.
class BootstrapGate extends ConsumerStatefulWidget {
  const BootstrapGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends ConsumerState<BootstrapGate> {
  bool _continueAnyway = false;

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(coreBootstrapProvider);

    return bootstrap.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => _failure(_errorMessage(context, error)),
      data: (result) {
        if (result.ready || _continueAnyway) {
          return widget.child;
        }
        final error = result.error;
        return _failure(
          error == null
              ? context.tr('bootstrap.failedShort')
              : _errorMessage(context, error),
        );
      },
    );
  }

  String _errorMessage(BuildContext context, Object error) {
    return context.tr(
      'bootstrap.failed',
      args: <String, Object?>{'error': context.trErrorObject(error)},
    );
  }

  Widget _failure(String message) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: EmptyState(
              icon: Icons.report_gmailerrorred_outlined,
              title: context.tr('bootstrap.unavailableTitle'),
              description: message,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: context.tr('bootstrap.retry'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => ref.invalidate(coreBootstrapProvider),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: context.tr('bootstrap.continue'),
                    onPressed: () => setState(() => _continueAnyway = true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
