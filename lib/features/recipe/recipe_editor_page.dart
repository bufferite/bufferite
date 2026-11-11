import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/buffer.dart';
import '../../core/engine/pipeline.dart';
import '../../core/engine/pipeline_executor.dart';
import '../../core/error/app_error.dart';
import '../../core/ui/components/app_button.dart';
import '../../core/ui/components/app_toast.dart';
import '../../core/ui/components/buffer_panel.dart';
import '../../core/ui/components/step_card.dart';
import '../../core/ui/design_tokens.dart';
import '../operations/operation_picker.dart';
import '../operations/operation_providers.dart';
import '../operations/step_config_sheet.dart';
import 'recipe.dart';
import 'recipe_id.dart';
import 'recipe_pipeline.dart';

/// Layout Recipe Editor sesuai `DESIGN.md` §8.2.
///
/// Preview live berjalan lewat pipeline dengan debounce 200 ms; eksekusi lama
/// dibatalkan saat input berubah.
class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({super.key, this.recipe});

  final Recipe? recipe;

  @override
  ConsumerState<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage> {
  static const Duration previewDebounce = Duration(milliseconds: 200);

  late final TextEditingController _nameController;
  late final TextEditingController _inputController;
  late List<RecipeStep> _steps;

  Timer? _debounce;
  CancellationToken? _cancellation;
  String? _previewText;
  AppError? _previewError;
  bool _previewing = false;

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
    _inputController.addListener(_schedulePreview);
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePreview());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancellation?.cancel();
    _inputController.removeListener(_schedulePreview);
    _nameController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            kind: widget.recipe?.output?.kind.name ?? 'text',
            content: _previewText,
            live: _previewing,
            errorMessage: _previewError?.message,
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
                  _schedulePreview();
                }),
                onTap: () => _configureStep(index),
                onDelete: () => _deleteStep(index),
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
    _schedulePreview();
  }

  void _deleteStep(int index) {
    final removed = _steps[index];
    setState(() {
      _steps = List<RecipeStep>.of(_steps)..removeAt(index);
    });
    _schedulePreview();
    showAppToast(
      context,
      message: 'Step dihapus',
      tone: AppToastTone.warning,
      undoLabel: 'Undo',
      onUndo: () {
        if (!mounted) {
          return;
        }
        setState(() {
          final restored = List<RecipeStep>.of(_steps);
          restored.insert(index.clamp(0, restored.length), removed);
          _steps = restored;
        });
        _schedulePreview();
      },
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
    _schedulePreview();
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
    _schedulePreview();
  }

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(previewDebounce, _runPreview);
  }

  Future<void> _runPreview() async {
    _cancellation?.cancel();
    final token = CancellationToken();
    _cancellation = token;

    if (_steps.isEmpty) {
      setState(() {
        _previewing = false;
        _previewText = _inputController.text.isEmpty
            ? null
            : _inputController.text;
        _previewError = null;
      });
      return;
    }

    setState(() {
      _previewing = true;
      _previewError = null;
    });

    final draft = Recipe(
      id: widget.recipe?.id ?? generateRecipeId(),
      name: _nameController.text.trim().isEmpty
          ? 'Draft'
          : _nameController.text.trim(),
      steps: _steps,
      input: TextBuffer(_inputController.text),
    );

    final executor = PipelineExecutor(
      registry: ref.read(operationRegistryProvider),
    );
    final result = await executor.execute(
      steps: draft.toPipelineSteps(),
      input: draft.input,
      cancellation: token,
    );
    if (token.isCancelled || !mounted) {
      return;
    }

    setState(() {
      _previewing = false;
      _previewError = result.errors.isEmpty ? null : result.errors.first;
      _previewText = result.output.kind == BufferKind.text
          ? result.output.asText()
          : null;
    });
  }

  void _save() {
    showAppToast(
      context,
      message: 'Menyimpan recipe (F09 lanjutan).',
      tone: AppToastTone.info,
    );
  }
}
