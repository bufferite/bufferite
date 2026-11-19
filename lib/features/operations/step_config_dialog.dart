import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/localized_error.dart';
import '../../core/i18n/operation_localization.dart';
import '../../core/plugin/operation_param.dart';
import '../../core/ui/components/app_button.dart';
import '../../core/ui/design_tokens.dart';

/// Dialog konfigurasi parameter satu step operasi.
///
/// Mengembalikan args yang sudah tervalidasi, atau `null` bila dibatalkan.
Future<Map<String, Object?>?> showStepConfigDialog(
  BuildContext context, {
  required String operationId,
  required String title,
  required List<OperationParam> params,
  required Map<String, Object?> initialArgs,
}) {
  return showDialog<Map<String, Object?>>(
    context: context,
    builder: (context) => StepConfigDialog(
      operationId: operationId,
      title: title,
      params: params,
      initialArgs: initialArgs,
    ),
  );
}

/// Dialog tengah untuk mengatur parameter step.
///
/// Dipakai menggantikan bottom sheet agar daftar step di panel samping tetap
/// terlihat dan konfigurasi tidak menutupi seluruh bagian bawah layar.
class StepConfigDialog extends StatefulWidget {
  const StepConfigDialog({
    super.key,
    required this.operationId,
    required this.title,
    required this.params,
    required this.initialArgs,
  });

  final String operationId;
  final String title;
  final List<OperationParam> params;
  final Map<String, Object?> initialArgs;

  @override
  State<StepConfigDialog> createState() => _StepConfigDialogState();
}

class _StepConfigDialogState extends State<StepConfigDialog> {
  final Map<String, TextEditingController> _textControllers =
      <String, TextEditingController>{};
  final Map<String, bool> _boolValues = <String, bool>{};
  final Map<String, String> _selectValues = <String, String>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final param in widget.params) {
      final current = widget.initialArgs[param.key] ?? param.defaultValue;
      switch (param.type) {
        case OperationParamType.boolean:
          _boolValues[param.key] = current is bool ? current : false;
        case OperationParamType.select:
          final fallback = param.options.isNotEmpty
              ? param.options.first.value
              : '';
          _selectValues[param.key] = current is String ? current : fallback;
        case OperationParamType.string:
        case OperationParamType.integer:
          _textControllers[param.key] = TextEditingController(
            text: current?.toString() ?? '',
          );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('common.close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (widget.params.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          context.tr('stepConfig.noParams'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    for (final param in widget.params) _field(param),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  AppButton(
                    label: context.tr('common.cancel'),
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: context.tr('common.apply'),
                    onPressed: _apply,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(OperationParam param) {
    final label = operationParamLabel(context, widget.operationId, param);
    final help = operationParamHelp(context, widget.operationId, param);
    switch (param.type) {
      case OperationParamType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: help != null ? Text(help) : null,
          value: _boolValues[param.key] ?? false,
          onChanged: (value) => setState(() => _boolValues[param.key] = value),
        );
      case OperationParamType.select:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: DropdownButtonFormField<String>(
            initialValue: _selectValues[param.key],
            decoration: InputDecoration(labelText: label, helperText: help),
            items: <DropdownMenuItem<String>>[
              for (final option in param.options)
                DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(
                    operationParamOptionLabel(
                      context,
                      widget.operationId,
                      param.key,
                      option,
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectValues[param.key] = value);
              }
            },
          ),
        );
      case OperationParamType.string:
      case OperationParamType.integer:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TextField(
            controller: _textControllers[param.key],
            keyboardType: param.type == OperationParamType.integer
                ? TextInputType.number
                : TextInputType.text,
            minLines: param.multiline ? 2 : 1,
            maxLines: param.multiline ? 5 : 1,
            obscureText: param.secret,
            decoration: InputDecoration(
              labelText: label,
              helperText: help,
              suffixText: param.isRequired ? '*' : null,
            ),
          ),
        );
    }
  }

  void _apply() {
    final raw = <String, Object?>{};
    for (final param in widget.params) {
      switch (param.type) {
        case OperationParamType.boolean:
          raw[param.key] = _boolValues[param.key] ?? false;
        case OperationParamType.select:
          raw[param.key] = _selectValues[param.key];
        case OperationParamType.string:
          final text = _textControllers[param.key]!.text;
          if (text.isNotEmpty) {
            raw[param.key] = text;
          }
        case OperationParamType.integer:
          final text = _textControllers[param.key]!.text.trim();
          if (text.isNotEmpty) {
            raw[param.key] = int.tryParse(text);
          }
      }
    }

    final resolved = resolveOperationArgs(widget.params, raw);
    if (!resolved.isSuccess) {
      setState(
        () => _error = context.trError(
          resolved.errorOrNull!,
          operationId: widget.operationId,
        ),
      );
      return;
    }
    Navigator.of(context).pop(resolved.valueOrNull);
  }
}
