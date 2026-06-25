import 'package:flutter/foundation.dart';

class AppConstants {
  // Backend Configuration
  // Default to Android Emulator '10.0.2.2' for native debug, else localhost/web host
  static String serverHost = kIsWeb ? Uri.base.host : "10.0.2.2";
  static const String defaultPort = "8000";
  
  static String get apiBaseUrl {
    final host = serverHost.contains(':') ? serverHost : "$serverHost:$defaultPort";
    return "http://$host/api/v1";
  }

  static String wsUrl(String sessionCode) {
    final host = serverHost.contains(':') ? serverHost : "$serverHost:$defaultPort";
    return "ws://$host/ws/$sessionCode";
  }

  // SharedPreferences Keys
  static const String keyThemeMode = "theme_mode";
  static const String keyUserToken = "user_token";
  static const String keyUserEmail = "user_email";
  static const String keyUserName = "user_name";
}
