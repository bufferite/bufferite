import 'dart:convert';
import 'dart:io';

import 'execution_log.dart';

/// Menyimpan log eksekusi sebagai JSONL di direktori `logs`.
///
/// File dibatasi [maxEntries] dan [maxBytes]; entri tertua dibuang lebih dulu.
final class ExecutionLogStore {
  ExecutionLogStore({
    required this.directory,
    this.maxEntries = 200,
    this.maxBytes = 256 * 1024,
  });

  static const String fileName = 'execution.log';

  final Future<Directory> Function() directory;
  final int maxEntries;
  final int maxBytes;

  Future<File> _file() async {
    final target = await directory();
    return File('${target.path}${Platform.pathSeparator}$fileName');
  }

  /// Menambahkan satu entri; file dibuat bila belum ada.
  Future<void> append(ExecutionLogEntry entry) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
    await _trim(file);
  }

  /// Entri terbaru lebih dulu.
  Future<List<ExecutionLogEntry>> recent({int limit = 50}) async {
    if (limit <= 0) {
      return const <ExecutionLogEntry>[];
    }
    final file = await _file();
    if (!file.existsSync()) {
      return const <ExecutionLogEntry>[];
    }
    final lines = await file.readAsLines();
    final entries = <ExecutionLogEntry>[];
    for (var index = lines.length - 1; index >= 0; index--) {
      final entry = ExecutionLogEntry.tryParse(lines[index]);
      if (entry != null) {
        entries.add(entry);
        if (entries.length >= limit) {
          break;
        }
      }
    }
    return List<ExecutionLogEntry>.unmodifiable(entries);
  }

  Future<void> clear() async {
    final file = await _file();
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> _trim(File file) async {
    final lines = await file.readAsLines();
    final length = await file.length();
    if (lines.length <= maxEntries && length <= maxBytes) {
      return;
    }
    final kept = lines.length > maxEntries
        ? lines.sublist(lines.length - maxEntries)
        : List<String>.of(lines);
    while (kept.length > 1 && utf8.encode(kept.join('\n')).length > maxBytes) {
      kept.removeAt(0);
    }
    await file.writeAsString(kept.map((line) => '$line\n').join(), flush: true);
  }
}

/// Mencatat log hanya bila pengguna sudah opt-in.
///
/// Kegagalan menulis log tidak pernah menggagalkan eksekusi recipe.
final class ExecutionLogService {
  ExecutionLogService({required this.store, required this.isEnabled});

  final ExecutionLogStore store;
  final Future<bool> Function() isEnabled;

  Future<void> record(ExecutionLogEntry entry) async {
    try {
      if (!await isEnabled()) {
        return;
      }
      await store.append(entry);
    } on Object {
      // Diagnostik bersifat best-effort.
    }
  }

  Future<List<ExecutionLogEntry>> recent({int limit = 50}) {
    return store.recent(limit: limit);
  }

  Future<void> clear() {
    return store.clear();
  }
}
