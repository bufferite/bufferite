import 'dart:async';

import 'sandbox.dart';

/// Cache runtime per plugin dengan LRU dan disposal idle.
///
/// Aturan (D09): satu instans per plugin, maksimal 4 entri, dispose setelah
/// 5 menit idle atau saat plugin dinonaktifkan/dihapus. Entri yang sedang
/// dipakai tidak akan dibuang; cache boleh sesaat melewati batas LRU daripada
/// memutus eksekusi yang berjalan.
final class RuntimeCache {
  RuntimeCache({
    this.maxEntries = 4,
    this.idleTimeout = const Duration(minutes: 5),
  }) {
    if (maxEntries < 1) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'Harus >= 1.');
    }
    if (idleTimeout <= Duration.zero) {
      throw ArgumentError.value(
        idleTimeout,
        'idleTimeout',
        'Harus lebih dari nol.',
      );
    }
  }

  final int maxEntries;
  final Duration idleTimeout;

  final Map<String, _CacheEntry> _entries = <String, _CacheEntry>{};
  int _clock = 0;
  var _disposed = false;

  /// Jumlah entri aktif (untuk test/diagnostik).
  int get length => _entries.length;

  /// Jalankan [body] dengan runtime untuk [key], membuatnya lewat [create]
  /// bila belum ada. Runtime dilepas dari "in-use" saat [body] selesai.
  Future<T> use<T>(
    String key,
    Future<SandboxRuntime> Function() create,
    Future<T> Function(SandboxRuntime runtime) body,
  ) async {
    if (_disposed) {
      throw StateError('RuntimeCache sudah dilepas.');
    }
    final entry = await _obtain(key, create);
    try {
      return await body(entry.runtime);
    } finally {
      _release(key, entry);
    }
  }

  /// Buang runtime [key] (plugin dinonaktifkan/dihapus).
  Future<void> evict(String key) async {
    final entry = _entries.remove(key);
    if (entry == null) {
      return;
    }
    entry.evicted = true;
    entry.idleTimer?.cancel();
    entry.idleTimer = null;
    if (entry.inUse == 0) {
      await _disposeRuntime(entry.runtime);
    }
  }

  /// Lepas semua runtime (dipakai saat aplikasi/shutdown atau test).
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final entries = _entries.values.toList();
    _entries.clear();
    for (final entry in entries) {
      entry.evicted = true;
      entry.idleTimer?.cancel();
      if (entry.inUse == 0) {
        await _disposeRuntime(entry.runtime);
      }
    }
  }

  Future<_CacheEntry> _obtain(
    String key,
    Future<SandboxRuntime> Function() create,
  ) async {
    final existing = _entries[key];
    if (existing != null) {
      existing.inUse++;
      existing.idleTimer?.cancel();
      existing.idleTimer = null;
      existing.useCounter = ++_clock;
      return existing;
    }

    final runtime = await create();
    final raced = _entries[key];
    if (raced != null) {
      // Pembuatan paralel untuk key yang sama: pakai yang lebih dulu masuk.
      await _disposeRuntime(runtime);
      raced.inUse++;
      raced.idleTimer?.cancel();
      raced.idleTimer = null;
      raced.useCounter = ++_clock;
      return raced;
    }

    final entry = _CacheEntry(runtime)
      ..inUse = 1
      ..useCounter = ++_clock;
    _entries[key] = entry;
    _prune();
    return entry;
  }

  void _release(String key, _CacheEntry entry) {
    entry.inUse--;
    if (entry.inUse > 0) {
      return;
    }
    if (entry.evicted || !identical(_entries[key], entry)) {
      unawaited(_disposeRuntime(entry.runtime));
      return;
    }
    entry.idleTimer?.cancel();
    entry.idleTimer = Timer(idleTimeout, () {
      if (entry.inUse > 0 || entry.evicted) {
        return;
      }
      if (identical(_entries[key], entry)) {
        _entries.remove(key);
      }
      unawaited(_disposeRuntime(entry.runtime));
    });
  }

  void _prune() {
    while (_entries.length > maxEntries) {
      _CacheEntry? oldest;
      String? oldestKey;
      for (final item in _entries.entries) {
        final entry = item.value;
        if (entry.inUse > 0) {
          continue;
        }
        if (oldest == null || entry.useCounter < oldest.useCounter) {
          oldest = entry;
          oldestKey = item.key;
        }
      }
      if (oldest == null || oldestKey == null) {
        return;
      }
      _entries.remove(oldestKey);
      oldest.evicted = true;
      oldest.idleTimer?.cancel();
      unawaited(_disposeRuntime(oldest.runtime));
    }
  }

  static Future<void> _disposeRuntime(SandboxRuntime runtime) async {
    if (runtime is! DisposableSandboxRuntime) {
      return;
    }
    try {
      await (runtime as DisposableSandboxRuntime).dispose();
    } on Object {
      // Disposal tidak boleh menggagalkan step berikutnya.
    }
  }
}

final class _CacheEntry {
  _CacheEntry(this.runtime);

  final SandboxRuntime runtime;
  int inUse = 0;
  int useCounter = 0;
  Timer? idleTimer;
  bool evicted = false;
}
