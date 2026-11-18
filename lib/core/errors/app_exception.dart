class AppException implements Exception {
  final String message;
  final int? statusCode;
  final List<String> errors;

  AppException({
    required this.message,
    this.statusCode,
    this.errors = const [],
  });

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([String message = 'Unable to connect to server. Please check your internet connection.'])
      : super(message: message, statusCode: null);
}

class ApiException extends AppException {
  ApiException({
    required super.message,
    super.statusCode,
    super.errors,
  });
}

class AuthException extends AppException {
  AuthException([String message = 'Authentication required or session expired.'])
      : super(message: message, statusCode: 401);
}

class ForbiddenException extends AppException {
  ForbiddenException([String message = 'Access forbidden: insufficient permissions.'])
      : super(message: message, statusCode: 403);
}
