import 'app_error.dart';

/// Hasil operasi yang bisa sukses atau gagal tanpa exception mentah.
sealed class Result<T> {
  const Result();

  bool get isSuccess;

  T? get valueOrNull;

  AppError? get errorOrNull;

  R when<R>({
    required R Function(T value) success,
    required R Function(AppError error) failure,
  });

  Result<R> map<R>(R Function(T value) mapper) {
    return when(success: (value) => Ok<R>(mapper(value)), failure: Err<R>.new);
  }

  Result<R> flatMap<R>(Result<R> Function(T value) mapper) {
    return when(success: mapper, failure: Err<R>.new);
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool get isSuccess => true;

  @override
  T? get valueOrNull => value;

  @override
  AppError? get errorOrNull => null;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(AppError error) failure,
  }) {
    return success(value);
  }
}

final class Err<T> extends Result<T> {
  const Err(this.error);

  final AppError error;

  @override
  bool get isSuccess => false;

  @override
  T? get valueOrNull => null;

  @override
  AppError? get errorOrNull => error;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(AppError error) failure,
  }) {
    return failure(error);
  }
}
