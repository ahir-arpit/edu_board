import 'package:flutter/foundation.dart';

class AppConstants {
  // Backend Configuration
  // Default to Android Emulator '10.0.2.2' for native debug, else localhost/web host
  static const String _backendUrlEnv = String.fromEnvironment('BACKEND_URL');
  static String? _customServerHost;

  static String get serverHost {
    if (_customServerHost != null) return _customServerHost!;
    if (_backendUrlEnv.isNotEmpty) {
      return _backendUrlEnv
          .replaceFirst('https://', '')
          .replaceFirst('http://', '');
    }
    return kIsWeb ? Uri.base.host : "10.0.2.2";
  }

  static set serverHost(String host) {
    _customServerHost = host;
  }

  static const String defaultPort = "8000";

  static bool get _useSecureProtocols {
    if (_backendUrlEnv.isNotEmpty) {
      return !_backendUrlEnv.startsWith('http://');
    }
    if (kIsWeb) {
      return Uri.base.scheme == 'https';
    }
    return false;
  }
  
  static String get apiBaseUrl {
    final host = serverHost.contains(':') ? serverHost : "$serverHost:$defaultPort";
    final finalHost = _backendUrlEnv.isNotEmpty ? serverHost : host;
    final scheme = _useSecureProtocols ? "https" : "http";
    return "$scheme://$finalHost/api/v1";
  }

  static String wsUrl(String sessionCode) {
    final host = serverHost.contains(':') ? serverHost : "$serverHost:$defaultPort";
    final finalHost = _backendUrlEnv.isNotEmpty ? serverHost : host;
    final scheme = _useSecureProtocols ? "wss" : "ws";
    return "$scheme://$finalHost/ws/$sessionCode";
  }

  // SharedPreferences Keys
  static const String keyThemeMode = "theme_mode";
  static const String keyUserToken = "user_token";
  static const String keyUserEmail = "user_email";
  static const String keyUserName = "user_name";
}
