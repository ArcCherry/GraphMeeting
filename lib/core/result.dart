/// 函数式结果类型
/// 
/// 用于优雅地处理成功/失败，替代 try-catch
/// 
/// 使用示例：
/// ```dart
/// Future<Result<User, NetworkError>> fetchUser(String id) async {
///   try {
///     final user = await api.getUser(id);
///     return Result.ok(user);
///   } on NetworkException catch (e) {
///     return Result.err(NetworkError(message: e.message));
///   }
/// }
/// ```
sealed class Result<T, E> {
  const Result();

  factory Result.ok(T value) = Ok<T, E>;
  factory Result.err(E error) = Err<T, E>;

  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;

  T? get okValue => (this as Ok<T, E>?)?.value;
  E? get errValue => (this as Err<T, E>?)?.error;

  /// 映射成功值
  Result<R, E> map<R>(R Function(T) f) {
    return switch (this) {
      Ok(value: final v) => Result.ok(f(v)),
      Err(error: final e) => Result.err(e),
    };
  }

  /// 映射错误值
  Result<T, R> mapErr<R>(R Function(E) f) {
    return switch (this) {
      Ok(value: final v) => Result.ok(v),
      Err(error: final e) => Result.err(f(e)),
    };
  }

  /// 链式操作
  Result<R, E> flatMap<R>(Result<R, E> Function(T) f) {
    return switch (this) {
      Ok(value: final v) => f(v),
      Err(error: final e) => Result.err(e),
    };
  }

  /// 获取值或默认值
  T getOrElse(T defaultValue) {
    return switch (this) {
      Ok(value: final v) => v,
      Err() => defaultValue,
    };
  }

  /// 获取值或抛出异常
  T unwrap() {
    return switch (this) {
      Ok(value: final v) => v,
      Err(error: final e) => throw StateError('Unwrapped Err: $e'),
    };
  }
}

class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);

  @override
  String toString() => 'Ok($value)';
}

class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);

  @override
  String toString() => 'Err($error)';
}

/// 异步结果扩展
extension FutureResult<T, E> on Future<Result<T, E>> {
  Future<Result<R, E>> map<R>(R Function(T) f) async {
    final result = await this;
    return result.map(f);
  }

  Future<Result<R, E>> flatMap<R>(Result<R, E> Function(T) f) async {
    final result = await this;
    return result.flatMap(f);
  }
}
