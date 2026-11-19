import 'package:flutter/widgets.dart';

import '../plugin/operation.dart';
import '../plugin/operation_param.dart';
import 'app_localizations.dart';

/// Nama operasi sesuai bahasa aktif, dengan fallback ke metadata manifest.
String operationName(BuildContext context, OperationDescriptor descriptor) {
  return context.trOr('operations.${descriptor.id}.name', descriptor.name);
}

/// Label kategori operasi sesuai bahasa aktif.
String operationCategoryLabel(
  BuildContext context,
  OperationCategory category,
) {
  return context.trOr('operationCategory.${category.name}', category.label);
}

/// Label parameter operasi sesuai bahasa aktif.
String operationParamLabel(
  BuildContext context,
  String operationId,
  OperationParam param,
) {
  return context.trOr(
    'operations.$operationId.params.${param.key}.label',
    param.label,
  );
}

/// Teks bantuan parameter, atau `null` bila parameter tidak punya bantuan.
String? operationParamHelp(
  BuildContext context,
  String operationId,
  OperationParam param,
) {
  final help = param.helpText;
  if (help == null) {
    return null;
  }
  return context.trOr('operations.$operationId.params.${param.key}.help', help);
}

/// Label opsi parameter select sesuai bahasa aktif.
String operationParamOptionLabel(
  BuildContext context,
  String operationId,
  String paramKey,
  OperationParamOption option,
) {
  return context.trOr(
    'operations.$operationId.params.$paramKey.options.${option.value}',
    option.label,
  );
}
