import '../../core/engine/pipeline.dart';
import 'recipe.dart';

/// Jembatan model Recipe (feature) ke engine pipeline (core).
extension RecipePipelineSteps on Recipe {
  List<PipelineStep> toPipelineSteps() {
    return List<PipelineStep>.unmodifiable(
      steps.map(
        (step) => PipelineStep(
          id: step.id,
          operationId: step.operationId,
          args: step.args,
          enabled: step.enabled,
        ),
      ),
    );
  }
}
