import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_param.dart';

final class CountingOperation implements Operation {
  CountingOperation({required this.id, required this.name});

  @override
  final String id;

  @override
  final String name;

  int calls = 0;

  @override
  OperationCategory get category => OperationCategory.utility;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io =>
      const OperationIO(input: BufferKind.text, output: BufferKind.text);

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    calls++;
    return input;
  }
}

final class SlowOperation implements Operation {
  const SlowOperation({
    this.id = 'test.slow',
    this.delay = const Duration(milliseconds: 100),
  });

  @override
  final String id;

  @override
  String get name => 'Slow Operation';

  final Duration delay;

  @override
  OperationCategory get category => OperationCategory.utility;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io =>
      const OperationIO(input: BufferKind.text, output: BufferKind.text);

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    await Future<void>.delayed(delay);
    return input;
  }
}

final class FailingOperation implements Operation {
  const FailingOperation({this.id = 'test.fail', required this.error});

  @override
  final String id;

  @override
  String get name => 'Failing Operation';

  final AppError error;

  @override
  OperationCategory get category => OperationCategory.utility;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io =>
      const OperationIO(input: BufferKind.text, output: BufferKind.text);

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    throw error;
  }
}

final class ExplodingOperation implements Operation {
  const ExplodingOperation({this.id = 'test.explode'});

  @override
  final String id;

  @override
  String get name => 'Exploding Operation';

  @override
  OperationCategory get category => OperationCategory.utility;

  @override
  List<OperationParam> get params => const <OperationParam>[];

  @override
  OperationIO get io =>
      const OperationIO(input: BufferKind.text, output: BufferKind.text);

  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async {
    throw StateError('boom');
  }
}
