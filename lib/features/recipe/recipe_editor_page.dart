import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/buffer.dart';
import '../../core/engine/pipeline.dart';
import '../../core/engine/pipeline_executor.dart';
import '../../core/error/app_error.dart';
import '../../core/storage/storage_providers.dart';
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
/// dibatalkan saat input berubah. Perubahan yang belum disimpan dijaga dialog.
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
  Map<String, AppError> _stepErrors = const <String, AppError>{};
  bool _dirty = false;
  bool _saving = false;

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
    _previewText = recipe?.output?.asText();
    _nameController.addListener(_markDirty);
    _inputController.addListener(_schedulePreview);
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePreview());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancellation?.cancel();
    _nameController.removeListener(_markDirty);
    _inputController.removeListener(_schedulePreview);
    _nameController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
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
                loading: _saving,
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
                state: _stateFor(_steps[index]),
                errorMessage: _stepErrors[_steps[index].id]?.message,
                onEnabledChanged: (value) => setState(() {
                  _steps[index] = _steps[index].copyWith(enabled: value);
                  _dirty = true;
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
      _dirty = true;
    });
    _schedulePreview();
  }

  void _deleteStep(int index) {
    final removed = _steps[index];
    setState(() {
      _steps = List<RecipeStep>.of(_steps)..removeAt(index);
      _dirty = true;
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
      _dirty = true;
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
      _dirty = true;
    });
    _schedulePreview();
  }

  void _schedulePreview() {
    _markDirty();
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
        _stepErrors = const <String, AppError>{};
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

    final stepErrors = <String, AppError>{
      for (final error in result.errors)
        if (error.stepId != null) error.stepId!: error,
    };
    setState(() {
      _previewing = false;
      _stepErrors = stepErrors;
      _previewError = stepErrors.values.isEmpty
          ? (result.errors.isEmpty ? null : result.errors.first)
          : null;
      _previewText = result.output.kind == BufferKind.text
          ? result.output.asText()
          : null;
    });
  }

  StepCardState _stateFor(RecipeStep step) {
    final error = _stepErrors[step.id];
    if (error != null) {
      return error.category == ErrorCategory.unsupported
          ? StepCardState.unsupported
          : StepCardState.error;
    }
    if (!_isSupported(step)) {
      return StepCardState.unsupported;
    }
    if (!step.enabled) {
      return StepCardState.disabled;
    }
    return StepCardState.normal;
  }

  bool _isSupported(RecipeStep step) {
    final entry = ref.read(operationRegistryProvider).byId(step.operationId);
    return entry != null && entry.descriptor.isSupported;
  }

  void _markDirty() {
    if (_dirty || !mounted) {
      return;
    }
    setState(() => _dirty = true);
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop || !_dirty) {
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang perubahan?'),
        content: const Text('Perubahan yang belum disimpan akan hilang.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    final draft = _buildDraft();
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      showAppToast(
        context,
        message: errors.first.message,
        tone: AppToastTone.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await ref.read(recipeRepositoryProvider).save(draft);
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _dirty = false;
      });
      showAppToast(
        context,
        message: 'Recipe disimpan',
        tone: AppToastTone.success,
      );
      Navigator.of(context).pop(saved);
    } on AppError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showAppToast(context, message: error.message, tone: AppToastTone.error);
    }
  }

  Recipe _buildDraft() {
    final inputText = _inputController.text;
    final existing = widget.recipe;
    return Recipe(
      id: existing?.id ?? generateRecipeId(),
      name: _nameController.text.trim(),
      steps: _steps,
      input: TextBuffer(inputText),
      meta: existing?.meta,
    );
  }
}
