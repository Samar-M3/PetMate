import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'PetMate';
  static const String appVersion = '1.0.0';

  // Laptop local LAN IP for physical device testing over Wi-Fi
  static const String laptopIp = '10.10.9.90';

  // API base URL:
  // Physical Android device over Wi-Fi: http://10.10.9.90:5000/api
  // Web / Windows: http://localhost:5000/api
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$laptopIp:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
