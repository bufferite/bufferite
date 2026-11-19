import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/diagnostics_providers.dart';
import '../../core/diagnostics/execution_log.dart';
import '../../core/engine/buffer.dart';
import '../../core/engine/pipeline.dart';
import '../../core/engine/pipeline_isolate.dart';
import '../../core/error/app_error.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/localized_error.dart';
import '../../core/i18n/operation_localization.dart';
import '../../core/runtime/sandbox.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/ui/components/app_button.dart';
import '../../core/ui/components/app_toast.dart';
import '../../core/ui/components/buffer_panel.dart';
import '../../core/ui/components/step_card.dart';
import '../../core/ui/design_tokens.dart';
import '../operations/operation_picker.dart';
import '../operations/operation_providers.dart';
import '../operations/step_config_dialog.dart';
import '../settings/settings_provider.dart';
import 'recipe.dart';
import 'recipe_id.dart';
import 'recipe_io.dart';
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
  FileBuffer? _inputFile;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _nameController = TextEditingController(text: recipe?.name ?? '');
    final input = recipe?.input;
    _inputFile = input != null && input.kind == BufferKind.file
        ? input as FileBuffer
        : null;
    _inputController = TextEditingController(
      text: input != null && input.kind == BufferKind.text
          ? input.asText()
          : '',
    );
    _steps = List<RecipeStep>.of(recipe?.steps ?? const <RecipeStep>[]);
    _previewText = recipe?.output?.kind == BufferKind.text
        ? recipe!.output!.preview().asText()
        : null;
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
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            widget.recipe == null
                ? context.tr('recipe.newTitle')
                : context.tr('recipe.editTitle'),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: context.tr('recipe.ingredients'),
              onPressed: _openStepsDrawer,
              icon: Badge.count(
                count: _steps.length,
                isLabelVisible: _steps.isNotEmpty,
                backgroundColor: theme.colorScheme.primary,
                textColor: theme.colorScheme.onPrimary,
                child: const Icon(Icons.local_grocery_store),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: context.tr('recipe.more'),
              onSelected: (value) {
                if (value == 'export') {
                  _exportRecipe();
                } else if (value == 'import') {
                  _importRecipe();
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'import',
                  child: Text(context.tr('recipe.import')),
                ),
                PopupMenuItem<String>(
                  value: 'export',
                  child: Text(context.tr('recipe.export')),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: AppButton(
                label: context.tr('recipe.save'),
                icon: Icons.save_outlined,
                loading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
        endDrawer: _stepsDrawer(theme),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr('recipe.nameLabel'),
              ),
              maxLength: maxRecipeNameLength,
            ),
            const SizedBox(height: AppSpacing.lg),
            _section(theme, context.tr('recipe.input')),
            const SizedBox(height: AppSpacing.sm),
            if (_inputFile != null)
              _fileInputCard()
            else
              TextField(
                controller: _inputController,
                minLines: 3,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'Roboto Mono', fontSize: 14),
                decoration: InputDecoration(
                  hintText: context.tr('recipe.inputHint'),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: context.tr('recipe.chooseFile'),
                variant: AppButtonVariant.ghost,
                icon: Icons.attach_file,
                onPressed: _pickInputFile,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            BufferPanel(
              label: context.tr('recipe.output'),
              kind: widget.recipe?.output?.kind.name ?? 'text',
              content: _previewText,
              live: _previewing,
              errorMessage: _previewError == null
                  ? null
                  : context.trError(_previewError!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title) {
    return Text(title, style: theme.textTheme.titleLarge);
  }

  void _openStepsDrawer() {
    FocusScope.of(context).unfocus();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Widget _stepsDrawer(ThemeData theme) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: screenWidth < 600 ? screenWidth : 400,
      child: SafeArea(
        child: Column(
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
                      '${context.tr('recipe.ingredients')} (${_steps.length})',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('recipe.closePanel'),
                    onPressed: () =>
                        _scaffoldKey.currentState?.closeEndDrawer(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: AppButton(
                label: context.tr('recipe.addIngredient'),
                variant: AppButtonVariant.secondary,
                icon: Icons.add,
                expand: true,
                onPressed: _addStep,
              ),
            ),
            Expanded(child: _stepsView(theme)),
          ],
        ),
      ),
    );
  }

  Widget _stepsView(ThemeData theme) {
    if (_steps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            context.tr('recipe.emptyIngredients'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }
    final registry = ref.read(operationRegistryProvider);
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      buildDefaultDragHandles: false,
      onReorderItem: _reorder,
      itemCount: _steps.length,
      itemBuilder: (context, index) {
        final step = _steps[index];
        final descriptor = registry.byId(step.operationId)?.descriptor;
        // Operasi tanpa parameter tidak perlu tombol atur (chevron).
        final configurable = descriptor == null || descriptor.params.isNotEmpty;
        return Padding(
          key: ValueKey<String>(step.id),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: StepCard(
              name: descriptor == null
                  ? step.operationId
                  : operationName(context, descriptor),
              category: descriptor == null
                  ? context.tr('recipe.operationFallback')
                  : operationCategoryLabel(context, descriptor.category),
              enabled: step.enabled,
              state: _stateFor(step),
              errorMessage: _stepErrors[step.id] == null
                  ? null
                  : context.trError(
                      _stepErrors[step.id]!,
                      operationId: step.operationId,
                    ),
              onEnabledChanged: (value) => setState(() {
                _steps[index] = step.copyWith(enabled: value);
                _dirty = true;
                _schedulePreview();
              }),
              onTap: configurable ? () => _configureStep(index) : null,
              onDelete: () => _deleteStep(index),
            ),
          ),
        );
      },
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
    // Tutup panel agar SnackBar + Undo terlihat di layar utama.
    _scaffoldKey.currentState?.closeEndDrawer();
    showAppToast(
      context,
      message: context.tr('recipe.ingredientsDeleted'),
      tone: AppToastTone.warning,
      undoLabel: context.tr('common.undo'),
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
        message: context.tr(
          'recipe.operationNotFound',
          args: <String, Object?>{'id': step.operationId},
        ),
        tone: AppToastTone.warning,
      );
      return;
    }
    final args = await showStepConfigDialog(
      context,
      operationId: descriptor.id,
      title: operationName(context, descriptor),
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
          ? context.tr('recipe.draftName')
          : _nameController.text.trim(),
      steps: _steps,
      input: _inputBuffer(),
    );

    final settings = ref.read(settingsProvider).value;
    final executor = IsolatePipelineExecutor(
      registry: ref.read(operationRegistryProvider),
      memoryLimitBytes:
          settings?.memoryLimitBytes ?? SandboxConfig.defaults.memoryLimitBytes,
    );
    final stopwatch = Stopwatch()..start();
    PipelineResult result;
    try {
      result = await executor.execute(
        steps: draft.toPipelineSteps(),
        input: draft.input,
        cancellation: token,
      );
    } on AppError catch (error) {
      stopwatch.stop();
      if (token.isCancelled || !mounted) {
        return;
      }
      setState(() {
        _previewing = false;
        _stepErrors = const <String, AppError>{};
        _previewError = error;
        _previewText = null;
      });
      return;
    }
    stopwatch.stop();
    if (mounted) {
      final outcome = result.cancelled
          ? ExecutionOutcome.cancelled
          : result.isSuccess
          ? ExecutionOutcome.success
          : ExecutionOutcome.failed;
      unawaited(
        ref
            .read(executionLogServiceProvider)
            .record(
              ExecutionLogEntry(
                timestamp: DateTime.now(),
                recipeId: widget.recipe?.id,
                recipeName: draft.name,
                operationIds: <String>[
                  for (final step in draft.steps)
                    if (step.enabled) step.operationId,
                ],
                durationMs: stopwatch.elapsedMilliseconds,
                outcome: outcome,
                errorCodes: <String>{
                  for (final error in result.errors) error.code,
                }.toList(growable: false),
              ),
            ),
      );
    }
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
          ? result.output.preview().asText()
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
        title: Text(context.tr('recipe.discardTitle')),
        content: Text(context.tr('recipe.discardBody')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('common.discard')),
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
        message: context.trError(errors.first),
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
        message: context.tr('recipe.saved'),
        tone: AppToastTone.success,
      );
      Navigator.of(context).pop(saved);
    } on AppError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showAppToast(
        context,
        message: context.trError(error),
        tone: AppToastTone.error,
      );
    }
  }

  Recipe _buildDraft() {
    final existing = widget.recipe;
    return Recipe(
      id: existing?.id ?? generateRecipeId(),
      name: _nameController.text.trim(),
      steps: _steps,
      input: _inputBuffer(),
      meta: existing?.meta,
    );
  }

  Future<void> _exportRecipe() async {
    final draft = _buildDraft();
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      showAppToast(
        context,
        message: context.trError(errors.first),
        tone: AppToastTone.error,
      );
      return;
    }
    try {
      final path = await RecipeIo().export(
        draft,
        dialogTitle: context.tr('recipe.exportDialogTitle'),
      );
      if (!mounted || path == null) {
        return;
      }
      showAppToast(
        context,
        message: context.tr('recipe.exported'),
        tone: AppToastTone.success,
      );
    } on AppError catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: context.trError(error),
          tone: AppToastTone.error,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: context.tr(
            'recipe.exportFailed',
            args: <String, Object?>{'error': context.trErrorObject(error)},
          ),
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> _importRecipe() async {
    try {
      final imported = await RecipeIo().import(
        dialogTitle: context.tr('recipe.importDialogTitle'),
      );
      if (!mounted) {
        return;
      }
      _applyImported(imported);
      showAppToast(
        context,
        message: context.tr('recipe.imported'),
        tone: AppToastTone.success,
      );
    } on AppError catch (error) {
      if (mounted && error.category != ErrorCategory.cancelled) {
        showAppToast(
          context,
          message: context.trError(error),
          tone: AppToastTone.error,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: context.tr(
            'recipe.importFailed',
            args: <String, Object?>{'error': context.trErrorObject(error)},
          ),
          tone: AppToastTone.error,
        );
      }
    }
  }

  void _applyImported(Recipe recipe) {
    _nameController.text = recipe.name;
    _inputController.text = recipe.input.kind == BufferKind.text
        ? recipe.input.asText()
        : '';
    setState(() {
      _steps = List<RecipeStep>.of(recipe.steps);
      _inputFile = recipe.input.kind == BufferKind.file
          ? recipe.input as FileBuffer
          : null;
      _dirty = true;
    });
    _schedulePreview();
  }

  Widget _fileInputCard() {
    final file = _inputFile!;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file_outlined),
        title: Text(file.name),
        subtitle: Text(context.trPlural('common.bytes', file.length)),
        trailing: IconButton(
          tooltip: context.tr('recipe.removeFile'),
          onPressed: () {
            setState(() {
              _inputFile = null;
              _dirty = true;
            });
            _schedulePreview();
          },
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }

  Buffer _inputBuffer() {
    return _inputFile ?? TextBuffer(_inputController.text);
  }

  Future<void> _pickInputFile() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: context.tr('recipe.pickFileTitle'),
      );
      if (file == null || !mounted) {
        return;
      }
      final path = file.path;
      if (path == null) {
        throw AppError(
          category: ErrorCategory.storage,
          code: 'recipe.file_unreadable',
          message: context.tr('recipe.fileUnreadable'),
        );
      }
      final handle = File(path);
      if (!handle.existsSync()) {
        throw AppError(
          category: ErrorCategory.storage,
          code: 'recipe.file_unreadable',
          message: context.tr('recipe.fileUnreadable'),
        );
      }
      final size = handle.lengthSync();
      final memoryLimit =
          ref.read(settingsProvider).value?.memoryLimitBytes ??
          SandboxConfig.defaults.memoryLimitBytes;
      if (size > memoryLimit) {
        throw AppError(
          category: ErrorCategory.runtime,
          code: 'runtime.file_too_large',
          message:
              'File ${file.name} berukuran $size byte, melebihi batas '
              'memori $memoryLimit byte.',
          details: <String, Object?>{'size': size, 'limit': memoryLimit},
        );
      }
      setState(() {
        _inputFile = FileBuffer(path: path, name: file.name, size: size);
        _inputController.text = '';
        _dirty = true;
      });
      _schedulePreview();
    } on AppError catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: context.trError(error),
          tone: AppToastTone.error,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: context.tr(
            'recipe.fileReadFailed',
            args: <String, Object?>{'error': context.trErrorObject(error)},
          ),
          tone: AppToastTone.error,
        );
      }
    }
  }
}
