import 'dart:async';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/runtime/runtime_cache.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeRuntime implements SandboxRuntime, DisposableSandboxRuntime {
  _FakeRuntime(this.name, this.log);

  final String name;
  final List<String> log;
  var disposed = false;

  @override
  Future<Buffer> execute(
    Buffer input,
    Map<String, Object?> args,
    SandboxContext context,
  ) async {
    return input;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    log.add('dispose:$name');
  }
}

void main() {
  late List<String> log;
  late RuntimeCache cache;

  setUp(() {
    log = <String>[];
    cache = RuntimeCache(
      maxEntries: 2,
      idleTimeout: const Duration(minutes: 5),
    );
  });

  Future<_FakeRuntime> use(String key, {Completer<void>? gate}) {
    return cache.use<_FakeRuntime>(
      key,
      () async {
        log.add('create:$key');
        return _FakeRuntime(key, log);
      },
      (runtime) async {
        if (gate != null) {
          await gate.future;
        }
        return runtime as _FakeRuntime;
      },
    );
  }

  test('runtime dipakai ulang untuk key yang sama', () async {
    final first = await use('a');
    final second = await use('a');

    expect(identical(first, second), isTrue);
    expect(log, <String>['create:a']);
    expect(cache.length, 1);
  });

  test('LRU membuang entri tertua saat melewati batas', () async {
    final a = await use('a');
    await use('b');
    await use('c');

    expect(cache.length, 2);
    expect(a.disposed, isTrue);
    expect(log, contains('dispose:a'));
  });

  test('entri yang sedang dipakai tidak dibuang', () async {
    final gate = Completer<void>();
    final held = use('a', gate: gate);
    await Future<void>.delayed(Duration.zero);

    await use('b');
    await use('c');

    expect(cache.length, 2, reason: 'entri sibuk dipertahankan, b dikeluarkan');
    gate.complete();
    final runtime = await held;
    expect(runtime.disposed, isFalse);
  });

  test('idle men-dispose runtime', () async {
    final shortCache = RuntimeCache(
      maxEntries: 2,
      idleTimeout: const Duration(milliseconds: 40),
    );
    final runtime = await shortCache.use<_FakeRuntime>(
      'a',
      () async => _FakeRuntime('a', log),
      (value) async => value as _FakeRuntime,
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(runtime.disposed, isTrue);
    expect(shortCache.length, 0);
    await shortCache.dispose();
  });

  test('evict men-dispose dan membuat ulang pada pemakaian berikutnya',
      () async {
    final first = await use('a');
    await cache.evict('a');

    expect(first.disposed, isTrue);
    expect(cache.length, 0);

    final second = await use('a');
    expect(identical(first, second), isFalse);
    expect(log.where((item) => item == 'create:a'), hasLength(2));
  });

  test('evict saat dipakai menunda disposal sampai selesai', () async {
    final gate = Completer<void>();
    final held = use('a', gate: gate);
    await Future<void>.delayed(Duration.zero);

    await cache.evict('a');

    expect(log.contains('dispose:a'), isFalse);
    gate.complete();
    final runtime = await held;
    await Future<void>.delayed(Duration.zero);

    expect(runtime.disposed, isTrue);
    expect(log, contains('dispose:a'));
  });

  test('dispose melepas semua runtime', () async {
    final a = await use('a');
    final b = await use('b');

    await cache.dispose();

    expect(a.disposed, isTrue);
    expect(b.disposed, isTrue);
    expect(cache.length, 0);
    await expectLater(use('c'), throwsA(isA<StateError>()));
  });
}
