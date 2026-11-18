import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plugin/operation_registry.dart';

/// Registry operasi in-memory aplikasi.
///
/// Diisi plugin loader/runtime pada F05/F13. Test dapat meng-override dengan
/// registry berisi operasi dummy.
final operationRegistryProvider = Provider<OperationRegistry>(
  (ref) => OperationRegistry(),
);

/// Dinaikkan setiap isi registry berubah (instal/hapus/aktivasi plugin) agar
/// daftar operasi di UI membaca ulang registry yang bersifat mutable.
final operationsRevisionProvider = NotifierProvider<OperationsRevision, int>(
  OperationsRevision.new,
);

class OperationsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
