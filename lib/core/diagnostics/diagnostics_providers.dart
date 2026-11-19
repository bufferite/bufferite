import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../storage/storage_providers.dart';
import 'execution_log_store.dart';

/// Penyimpanan log eksekusi di `<application support>/logs/execution.log`.
final executionLogStoreProvider = Provider<ExecutionLogStore>((ref) {
  return ExecutionLogStore(
    directory: () async {
      final support = await getApplicationSupportDirectory();
      return Directory('${support.path}/logs');
    },
  );
});

/// Pencatat log yang membaca preferensi opt-in langsung dari repository.
final executionLogServiceProvider = Provider<ExecutionLogService>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return ExecutionLogService(
    store: ref.watch(executionLogStoreProvider),
    isEnabled: () async => (await settings.load()).optInLogging,
  );
});
