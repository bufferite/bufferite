import 'dart:io';

import 'package:bufferite/core/diagnostics/execution_log.dart';
import 'package:bufferite/core/diagnostics/execution_log_store.dart';
import 'package:flutter_test/flutter_test.dart';

ExecutionLogEntry _entry(String name, {ExecutionOutcome? outcome}) {
  return ExecutionLogEntry(
    timestamp: DateTime(2026, 11, 19, 10, 0),
    recipeName: name,
    operationIds: const <String>['core.reverse'],
    durationMs: 5,
    outcome: outcome ?? ExecutionOutcome.success,
  );
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bufferite_execution_log_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      await temp.delete(recursive: true);
    }
  });

  ExecutionLogStore store({int maxEntries = 200}) {
    return ExecutionLogStore(
      directory: () async => temp,
      maxEntries: maxEntries,
    );
  }

  test('append lalu recent mengembalikan entri terbaru lebih dulu', () async {
    final log = store();
    await log.append(_entry('Pertama'));
    await log.append(_entry('Kedua', outcome: ExecutionOutcome.failed));

    final entries = await log.recent();

    expect(entries.map((entry) => entry.recipeName), <String>[
      'Kedua',
      'Pertama',
    ]);
    expect(entries.first.outcome, ExecutionOutcome.failed);
    expect(File('${temp.path}/execution.log').existsSync(), isTrue);
  });

  test('recent menghormati batas limit', () async {
    final log = store();
    for (var index = 0; index < 5; index++) {
      await log.append(_entry('Recipe $index'));
    }

    final entries = await log.recent(limit: 2);

    expect(entries.map((entry) => entry.recipeName), <String>[
      'Recipe 4',
      'Recipe 3',
    ]);
    expect(await log.recent(limit: 0), isEmpty);
  });

  test('trim membuang entri tertua saat melebihi maxEntries', () async {
    final log = store(maxEntries: 3);
    for (var index = 0; index < 5; index++) {
      await log.append(_entry('Recipe $index'));
    }

    final entries = await log.recent(limit: 10);

    expect(entries.map((entry) => entry.recipeName), <String>[
      'Recipe 4',
      'Recipe 3',
      'Recipe 2',
    ]);
  });

  test('baris rusak dilewati saat membaca', () async {
    final file = File('${temp.path}/execution.log');
    await file.writeAsString(
      'bukan json\n'
      '${_jsonLine('Valid')}\n',
    );

    final entries = await store().recent();

    expect(entries.map((entry) => entry.recipeName), <String>['Valid']);
  });

  test('clear menghapus file log', () async {
    final log = store();
    await log.append(_entry('Alpha'));

    await log.clear();

    expect(await log.recent(), isEmpty);
  });

  test('service tidak menulis saat opt-out', () async {
    final log = store();
    final service = ExecutionLogService(
      store: log,
      isEnabled: () async => false,
    );

    await service.record(_entry('Alpha'));

    expect(await log.recent(), isEmpty);
  });

  test('service menulis saat opt-in', () async {
    final log = store();
    final service = ExecutionLogService(
      store: log,
      isEnabled: () async => true,
    );

    await service.record(_entry('Alpha'));

    expect((await service.recent()).map((entry) => entry.recipeName), <String>[
      'Alpha',
    ]);
  });

  test('kegagalan menulis log tidak dilempar ke pemanggil', () async {
    final broken = ExecutionLogStore(
      directory: () async => Directory('${temp.path}/file/not-a-directory'),
    );
    final service = ExecutionLogService(
      store: broken,
      isEnabled: () async => true,
    );
    await File('${temp.path}/file').writeAsString('bukan direktori');

    await expectLater(service.record(_entry('Alpha')), completes);
  });
}

String _jsonLine(String name) {
  return '{"timestamp":"2026-11-19T10:00:00Z","recipeName":"$name",'
      '"operationIds":["core.reverse"],"durationMs":5,'
      '"outcome":"success","errorCodes":[]}';
}
