/// Result type for predictable error propagation across module boundaries
/// (Architecture.md — modules communicate through interfaces).
import 'package:pokatuha/core/errors/app_error.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get value => switch (this) {
        Success(value: final v) => v,
        Failure() => null,
      };

  AppError? get error => switch (this) {
        Success() => null,
        Failure(error: final e) => e,
      };

  R map<R>(R Function(T value) onSuccess,
          R Function(AppError error) onFailure) =>
      switch (this) {
        Success(value: final v) => onSuccess(v),
        Failure(error: final e) => onFailure(e),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  @override
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  @override
  final AppError error;
}
