import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'PetMate';
  static const String appVersion = '1.0.0';

  // Laptop local LAN IP for physical device testing over Wi-Fi
  static const String defaultLanIp = 'localhost';

  // Backend host:
  // - Web / Windows desktop -> localhost
  // - Physical Android device -> defaultLanIp
  // - Can be overridden anytime with:
  //     flutter run --dart-define=BACKEND_HOST=localhost (for adb reverse)
  //     flutter run --dart-define=BACKEND_HOST=<new_ip>
  static String get _host {
    const fromEnv = String.fromEnvironment('BACKEND_HOST');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) return 'localhost';

    if (defaultTargetPlatform == TargetPlatform.android) {
      return defaultLanIp;
    }

    return 'localhost';
  }

  static const int backendPort = 5000;

  static String get baseUrl => 'http://$_host:$backendPort/api';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
