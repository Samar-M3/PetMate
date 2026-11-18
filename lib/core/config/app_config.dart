import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'PetMate';
  static const String appVersion = '1.0.0';

  /// Set to true when testing on a physical Android device using ADB reverse (default)
  /// Set to false if testing strictly on an Android emulator without ADB reverse
  static const bool useAdbReverse = true;

  // API base URL:
  // For physical Android device with `adb reverse tcp:5000 tcp:5000`: http://127.0.0.1:5000/api
  // For Android emulator (without reverse): http://10.0.2.2:5000/api
  // For Web / Windows / iOS simulator: http://localhost:5000/api
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (useAdbReverse) {
        return 'http://127.0.0.1:5000/api';
      }
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
