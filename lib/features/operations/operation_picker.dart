import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/plugin/operation.dart';
import '../../core/plugin/operation_registry.dart';
import '../../core/ui/components/app_badge.dart';
import '../../core/ui/design_tokens.dart';

/// Bottom sheet Operation Picker sesuai `DESIGN.md` §6.4.
///
/// Search sticky di atas, chip kategori/favorit, daftar operasi dengan badge
/// tier. Mengembalikan descriptor terpilih, atau `null` bila ditutup.
Future<OperationDescriptor?> showOperationPicker(
  BuildContext context, {
  required OperationRegistry registry,
  Set<String> favorites = const <String>{},
}) {
  return showModalBottomSheet<OperationDescriptor>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: OperationPicker(registry: registry, favorites: favorites),
    ),
  );
}

class OperationPicker extends StatefulWidget {
  const OperationPicker({
    super.key,
    required this.registry,
    this.favorites = const <String>{},
  });

  final OperationRegistry registry;
  final Set<String> favorites;

  @override
  State<OperationPicker> createState() => _OperationPickerState();
}

class _OperationPickerState extends State<OperationPicker> {
  String _query = '';
  OperationCategory? _category;
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = _chips(context);
    final results = _filtered();

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
            decoration: InputDecoration(
              hintText: context.tr('picker.searchHint'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: <Widget>[
              for (final chip in chips) ...<Widget>[
                FilterChip(
                  label: Text(chip.label),
                  selected: chip.selected,
                  onSelected: (value) => setState(chip.onSelected),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      context.tr('picker.noMatch'),
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

  List<_ChipData> _chips(BuildContext context) {
    return <_ChipData>[
      _ChipData(
        label: context.tr('picker.favorites'),
        selected: _favoritesOnly,
        onSelected: () => _favoritesOnly = !_favoritesOnly,
      ),
      for (final category in OperationCategory.values)
        _ChipData(
          label: category.label,
          selected: _category == category,
          onSelected: () => _category = _category == category ? null : category,
        ),
    ];
  }

  List<RegisteredOperation> _filtered() {
    Iterable<RegisteredOperation> items = widget.registry.search(
      _query,
      includeUnsupported: true,
    );
    final category = _category;
    if (category != null) {
      items = items.where((entry) => entry.descriptor.category == category);
    }
    if (_favoritesOnly) {
      items = items.where(
        (entry) => widget.favorites.contains(entry.descriptor.id),
      );
    }
    return List<RegisteredOperation>.unmodifiable(items);
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

final class _ChipData {
  const _ChipData({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
}
