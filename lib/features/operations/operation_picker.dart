import 'package:flutter/material.dart';

import '../../core/plugin/operation.dart';
import '../../core/plugin/operation_registry.dart';
import '../../core/ui/components/app_badge.dart';
import '../../core/ui/design_tokens.dart';

/// Bottom sheet Operation Picker sesuai `DESIGN.md` §6.4.
///
/// Mengembalikan descriptor terpilih, atau `null` bila ditutup.
Future<OperationDescriptor?> showOperationPicker(
  BuildContext context, {
  required OperationRegistry registry,
}) {
  return showModalBottomSheet<OperationDescriptor>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: OperationPicker(registry: registry),
    ),
  );
}

class OperationPicker extends StatefulWidget {
  const OperationPicker({super.key, required this.registry});

  final OperationRegistry registry;

  @override
  State<OperationPicker> createState() => _OperationPickerState();
}

class _OperationPickerState extends State<OperationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = widget.registry.search(_query, includeUnsupported: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TextField(
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Cari operasi',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Tidak ada operasi cocok',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  itemCount: results.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) => _tile(results[index], theme),
                ),
        ),
      ],
    );
  }

  Widget _tile(RegisteredOperation entry, ThemeData theme) {
    final descriptor = entry.descriptor;
    return ListTile(
      enabled: descriptor.isSupported,
      title: Text(descriptor.name),
      subtitle: Text(descriptor.category.label),
      trailing: AppBadge(label: descriptor.tier.name),
      onTap: descriptor.isSupported
          ? () => Navigator.of(context).pop(descriptor)
          : null,
    );
  }
}
