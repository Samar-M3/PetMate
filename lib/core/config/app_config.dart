import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'PetMate';
  static const String appVersion = '1.0.0';

  // Default API base URL:
  // For Android emulator: 10.0.2.2
  // For Web / Windows / iOS simulator: localhost
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/v1';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api/v1';
    }
    return 'http://localhost:5000/api/v1';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
