import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plugin/operation_registry.dart';

/// Registry operasi in-memory aplikasi.
///
/// Diisi plugin loader/runtime pada F05/F13. Test dapat meng-override dengan
/// registry berisi operasi dummy.
final operationRegistryProvider = Provider<OperationRegistry>(
  (ref) => OperationRegistry(),
);
