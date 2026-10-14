/// نمط النتيجة الموحّد `Result<T>` للعمليات التي قد تنجح أو تفشل.
/// يوفر أسلوباً معمارياً آمناً للتعامل مع الأخطاء بدون رمي استثناءات غير متوقعة.
sealed class Result<T> {
  const Result();

  /// هل العملية نجحت؟
  bool get isSuccess => this is Success<T>;

  /// هل العملية فشلت؟
  bool get isFailure => this is Failure<T>;

  /// الحصول على البيانات إن وُجدت، أو null
  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        Failure() => null,
      };

  /// الحصول على رسالة الخطأ إن وُجدت، أو null
  String? get errorMessageOrNull => switch (this) {
        Success() => null,
        Failure(:final message) => message,
      };

  /// مطابقة الحالات بشكل دالي (Pattern Matching)
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Object? exception) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Failure(:final message, :final exception) => failure(message, exception),
    };
  }

  /// تنفيذ دالة آمنة وتغليف نتيجتها تلقائياً في Result
  static Future<Result<R>> guard<R>(Future<R> Function() action, {String defaultErrorMessage = 'حدث خطأ غير متوقع'}) async {
    try {
      final res = await action();
      return Success(res);
    } catch (e) {
      return Failure(defaultErrorMessage, e);
    }
  }

  /// تنفيذ دالة تزامنية آمنة
  static Result<R> guardSync<R>(R Function() action, {String defaultErrorMessage = 'حدث خطأ غير متوقع'}) {
    try {
      final res = action();
      return Success(res);
    } catch (e) {
      return Failure(defaultErrorMessage, e);
    }
  }
}

/// حالة النجاح
class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  String toString() => 'Success(data: $data)';
}

/// حالة الفشل
class Failure<T> extends Result<T> {
  final String message;
  final Object? exception;
  const Failure(this.message, [this.exception]);

  @override
  String toString() => 'Failure(message: $message, exception: $exception)';
}
