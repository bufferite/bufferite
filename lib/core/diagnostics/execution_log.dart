import 'dart:convert';

/// Hasil satu eksekusi pipeline yang dicatat untuk diagnostik.
enum ExecutionOutcome { success, failed, cancelled }

/// Metadata eksekusi yang aman disimpan lokal.
///
/// Input, output, dan args step tidak pernah ikut dicatat.
final class ExecutionLogEntry {
  const ExecutionLogEntry({
    required this.timestamp,
    required this.recipeName,
    required this.operationIds,
    required this.durationMs,
    required this.outcome,
    this.recipeId,
    this.errorCodes = const <String>[],
  });

  final DateTime timestamp;
  final String? recipeId;
  final String recipeName;
  final List<String> operationIds;
  final int durationMs;
  final ExecutionOutcome outcome;
  final List<String> errorCodes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestamp': timestamp.toUtc().toIso8601String(),
      'recipeId': ?recipeId,
      'recipeName': recipeName,
      'operationIds': operationIds,
      'durationMs': durationMs,
      'outcome': outcome.name,
      'errorCodes': errorCodes,
    };
  }

  /// Mengembalikan `null` untuk baris kosong/rusak agar log lama tidak
  /// menggagalkan pembacaan.
  static ExecutionLogEntry? tryParse(String line) {
    if (line.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final timestamp = DateTime.tryParse(
        decoded['timestamp'] as String? ?? '',
      );
      final recipeName = decoded['recipeName'];
      final durationMs = decoded['durationMs'];
      final outcomeName = decoded['outcome'];
      final operationIds = decoded['operationIds'];
      final errorCodes = decoded['errorCodes'];
      if (timestamp == null ||
          recipeName is! String ||
          durationMs is! int ||
          outcomeName is! String ||
          operationIds is! List<Object?> ||
          errorCodes is! List<Object?>) {
        return null;
      }
      ExecutionOutcome? outcome;
      for (final candidate in ExecutionOutcome.values) {
        if (candidate.name == outcomeName) {
          outcome = candidate;
          break;
        }
      }
      if (outcome == null) {
        return null;
      }
      return ExecutionLogEntry(
        timestamp: timestamp.toLocal(),
        recipeId: decoded['recipeId'] as String?,
        recipeName: recipeName,
        operationIds: operationIds.whereType<String>().toList(growable: false),
        durationMs: durationMs,
        outcome: outcome,
        errorCodes: errorCodes.whereType<String>().toList(growable: false),
      );
    } on FormatException {
      return null;
    }
  }
}
