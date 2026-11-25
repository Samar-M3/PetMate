class AppConfig {
  static const String appName = 'PetMate';
  static const String appVersion = '1.0.0';

  static const String baseUrl = 'http://127.0.0.1:5000/api';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
