library;

class AndroidNativeError {
  const AndroidNativeError({
    required this.code,
    required this.message,
    required this.recoverable,
    this.details = const <String, dynamic>{},
  });

  final String code;
  final String message;
  final bool recoverable;
  final Map<String, dynamic> details;

  factory AndroidNativeError.fromMap(Map<dynamic, dynamic> map) {
    return AndroidNativeError(
      code: map['code']?.toString() ?? 'native_failure',
      message: map['message']?.toString() ?? 'Native operation failed',
      recoverable: map['recoverable'] == true,
      details: asStringMap(map['details']),
    );
  }

  Map<String, dynamic> toDebugMap() {
    return {
      'code': code,
      'message': message,
      'recoverable': recoverable,
      'details': details,
    };
  }

  @override
  String toString() => 'code=$code, message=$message';
}

class AndroidNativeResult<T> {
  const AndroidNativeResult._({required this.ok, this.data, this.error});

  final bool ok;
  final T? data;
  final AndroidNativeError? error;

  factory AndroidNativeResult.ok(T data) =>
      AndroidNativeResult._(ok: true, data: data);

  factory AndroidNativeResult.error(
    String code,
    String message, {
    bool recoverable = true,
    Map<String, dynamic> details = const <String, dynamic>{},
  }) {
    return AndroidNativeResult._(
      ok: false,
      error: AndroidNativeError(
        code: code,
        message: message,
        recoverable: recoverable,
        details: details,
      ),
    );
  }

  factory AndroidNativeResult.unsupported() => AndroidNativeResult.error(
    'unsupported_android_version',
    'Android native capability is only available on Android.',
  );

  factory AndroidNativeResult.fromEnvelope(
    Object? envelope,
    T Function(Object? data) convert,
  ) {
    final map = envelope is Map ? envelope : const <dynamic, dynamic>{};
    if (map['ok'] == true) {
      return AndroidNativeResult.ok(convert(map['data']));
    }
    final error = map['error'];
    return AndroidNativeResult._(
      ok: false,
      error: error is Map
          ? AndroidNativeError.fromMap(error)
          : const AndroidNativeError(
            code: 'native_failure',
            message: 'Native operation failed',
            recoverable: true,
            details: <String, dynamic>{},
          ),
    );
  }
}

Map<String, dynamic> asStringMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asStringMapList(Object? value) {
  if (value is List) {
    return value.map(asStringMap).toList(growable: false);
  }
  return const [];
}
