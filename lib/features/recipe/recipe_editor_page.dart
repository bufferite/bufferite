import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/buffer.dart';
import '../../core/ui/components/app_button.dart';
import '../../core/ui/components/app_toast.dart';
import '../../core/ui/components/buffer_panel.dart';
import '../../core/ui/components/step_card.dart';
import '../../core/ui/design_tokens.dart';
import '../operations/operation_picker.dart';
import '../operations/operation_providers.dart';
import '../operations/step_config_sheet.dart';
import 'recipe.dart';

/// Layout Recipe Editor sesuai `DESIGN.md` §8.2.
///
/// F09-T01 menyediakan kerangka: nama, input, daftar step, output, dan aksi
/// simpan. Pipeline, picker, dan konfigurasi step diisi task F09 berikutnya.
class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({super.key, this.recipe});

  final Recipe? recipe;

  @override
  ConsumerState<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _inputController;
  late List<RecipeStep> _steps;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _nameController = TextEditingController(text: recipe?.name ?? '');
    final input = recipe?.input;
    _inputController = TextEditingController(
      text: input != null && input.kind == BufferKind.text
          ? input.asText()
          : '',
    );
    _steps = List<RecipeStep>.of(recipe?.steps ?? const <RecipeStep>[]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final output = widget.recipe?.output;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Recipe Baru' : 'Edit Recipe'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: AppButton(
              label: 'Simpan',
              icon: Icons.save_outlined,
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nama recipe'),
            maxLength: maxRecipeNameLength,
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, 'Input'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _inputController,
            minLines: 3,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'Roboto Mono', fontSize: 14),
            decoration: const InputDecoration(hintText: 'Tempel data input'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, 'Step'),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Tambah step',
              variant: AppButtonVariant.secondary,
              icon: Icons.add,
              onPressed: _addStep,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _stepsView(theme),
          const SizedBox(height: AppSpacing.lg),
          _section(theme, 'Output'),
          const SizedBox(height: AppSpacing.sm),
          BufferPanel(
            label: 'Output',
            kind: output?.kind.name ?? 'text',
            content: output?.asText(),
          ),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, String title) {
    return Text(title, style: theme.textTheme.titleLarge);
  }

  Widget _stepsView(ThemeData theme) {
    if (_steps.isEmpty) {
      return Text(
        'Belum ada step. Tambahkan operasi dari Library.',
        style: theme.textTheme.bodySmall,
      );
    }
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: _reorder,
      children: <Widget>[
        for (var index = 0; index < _steps.length; index++)
          Padding(
            key: ValueKey<String>(_steps[index].id),
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ReorderableDelayedDragStartListener(
              index: index,
              child: StepCard(
                name: _steps[index].operationId,
                category: _steps[index].args.keys.isEmpty
                    ? 'Operasi'
                    : _steps[index].args.keys.join(', '),
                enabled: _steps[index].enabled,
                onEnabledChanged: (value) => setState(() {
                  _steps[index] = _steps[index].copyWith(enabled: value);
                }),
                onTap: () => _configureStep(index),
              ),
            ),
          ),
      ],
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      final step = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, step);
    });
  }

  void _save() {
    showAppToast(
      context,
      message: 'Menyimpan recipe (F09 lanjutan).',
      tone: AppToastTone.info,
    );
  }

  Future<void> _addStep() async {
    final descriptor = await showOperationPicker(
      context,
      registry: ref.read(operationRegistryProvider),
    );
    if (descriptor == null || !mounted) {
      return;
    }
    setState(() {
      _steps = <RecipeStep>[
        ..._steps,
        RecipeStep(
          id: 'step-${_steps.length}-${descriptor.id}',
          operationId: descriptor.id,
        ),
      ];
    });
  }

  Future<void> _configureStep(int index) async {
    final step = _steps[index];
    final descriptor = ref
        .read(operationRegistryProvider)
        .byId(step.operationId)
        ?.descriptor;
    if (descriptor == null) {
      showAppToast(
        context,
        message: 'Operasi ${step.operationId} tidak ditemukan.',
        tone: AppToastTone.warning,
      );
      return;
    }
    final args = await showStepConfigSheet(
      context,
      title: descriptor.name,
      params: descriptor.params,
      initialArgs: step.args,
    );
    if (args == null || !mounted) {
      return;
    }
    setState(() {
      _steps[index] = step.copyWith(args: args);
    });
  }
}
