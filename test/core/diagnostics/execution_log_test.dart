import 'dart:convert';

import 'package:bufferite/core/diagnostics/execution_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON round-trip mempertahankan metadata eksekusi', () {
    final timestamp = DateTime(2026, 11, 19, 10, 30, 5);
    final entry = ExecutionLogEntry(
      timestamp: timestamp,
      recipeId: 'recipe-1',
      recipeName: 'Alpha',
      operationIds: const <String>['core.base64_decode', 'core.gzip'],
      durationMs: 12,
      outcome: ExecutionOutcome.failed,
      errorCodes: const <String>['plugin.timeout'],
    );

    final parsed = ExecutionLogEntry.tryParse(jsonEncode(entry.toJson()));

    expect(parsed, isNotNull);
    expect(parsed!.timestamp.isAtSameMomentAs(timestamp), isTrue);
    expect(parsed.recipeId, 'recipe-1');
    expect(parsed.recipeName, 'Alpha');
    expect(parsed.operationIds, <String>['core.base64_decode', 'core.gzip']);
    expect(parsed.durationMs, 12);
    expect(parsed.outcome, ExecutionOutcome.failed);
    expect(parsed.errorCodes, <String>['plugin.timeout']);
  });

  test('recipeId opsional tidak ditulis saat null', () {
    final entry = ExecutionLogEntry(
      timestamp: DateTime(2026, 11, 19),
      recipeName: 'Draft',
      operationIds: const <String>[],
      durationMs: 0,
      outcome: ExecutionOutcome.success,
    );

    expect(entry.toJson().containsKey('recipeId'), isFalse);
  });

  test('baris kosong dan JSON rusak diabaikan', () {
    expect(ExecutionLogEntry.tryParse(''), isNull);
    expect(ExecutionLogEntry.tryParse('bukan json'), isNull);
    expect(ExecutionLogEntry.tryParse('{"recipeName": 42}'), isNull);
    expect(
      ExecutionLogEntry.tryParse(
        '{"timestamp":"2026-11-19T10:00:00Z","recipeName":"A",'
        '"operationIds":[],"durationMs":1,"outcome":"unknown",'
        '"errorCodes":[]}',
      ),
      isNull,
    );
    expect(
      ExecutionLogEntry.tryParse(
        '{"timestamp":null,"recipeName":"A","operationIds":[],'
        '"durationMs":1,"outcome":"success","errorCodes":[]}',
      ),
      isNull,
    );
  });
}
