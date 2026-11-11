import 'package:flutter/material.dart';

import '../../core/plugin/operation_param.dart';
import '../../core/ui/components/app_button.dart';
import '../../core/ui/design_tokens.dart';

/// Sheet konfigurasi parameter satu step operasi.
///
/// Mengembalikan args yang sudah tervalidasi, atau `null` bila dibatalkan.
Future<Map<String, Object?>?> showStepConfigSheet(
  BuildContext context, {
  required String title,
  required List<OperationParam> params,
  required Map<String, Object?> initialArgs,
}) {
  return showModalBottomSheet<Map<String, Object?>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: StepConfigSheet(
          title: title,
          params: params,
          initialArgs: initialArgs,
        ),
      ),
    ),
  );
}

class StepConfigSheet extends StatefulWidget {
  const StepConfigSheet({
    super.key,
    required this.title,
    required this.params,
    required this.initialArgs,
  });

  final String title;
  final List<OperationParam> params;
  final Map<String, Object?> initialArgs;

  @override
  State<StepConfigSheet> createState() => _StepConfigSheetState();
}

class _StepConfigSheetState extends State<StepConfigSheet> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(widget.title, style: theme.textTheme.titleLarge),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: <Widget>[
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
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppButton(label: 'Terapkan', expand: true, onPressed: _apply),
        ),
      ],
    );
  }

  Widget _field(OperationParam param) {
    switch (param.type) {
      case OperationParamType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(param.label),
          subtitle: param.helpText != null ? Text(param.helpText!) : null,
          value: _boolValues[param.key] ?? false,
          onChanged: (value) => setState(() => _boolValues[param.key] = value),
        );
      case OperationParamType.select:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: DropdownButtonFormField<String>(
            initialValue: _selectValues[param.key],
            decoration: InputDecoration(
              labelText: param.label,
              helperText: param.helpText,
            ),
            items: <DropdownMenuItem<String>>[
              for (final option in param.options)
                DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label),
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
              labelText: param.label,
              helperText: param.helpText,
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
      setState(() => _error = resolved.errorOrNull!.message);
      return;
    }
    Navigator.of(context).pop(resolved.valueOrNull);
  }
}
