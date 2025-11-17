import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration helper
///
/// Provides type-safe access to environment variables
class EnvConfig {
  /// Get an environment variable
  /// Throws an exception if the key is not found (in debug mode)
  static String get(String key, {String? fallback}) {
    final value = dotenv.env[key];

    if (value == null || value.isEmpty) {
      if (fallback != null) {
        return fallback;
      }
      throw Exception(
        'Environment variable "$key" not found. '
        'Make sure you have a .env file with this key.',
      );
    }

    return value;
  }

  /// Get an environment variable or return null if not found
  static String? getOrNull(String key) {
    return dotenv.env[key];
  }

  /// Check if an environment variable exists
  static bool has(String key) {
    final value = dotenv.env[key];
    return value != null && value.isNotEmpty;
  }

  // Predefined environment variables for type safety

  /// Google Web OAuth Client ID (for web platform)
  /// Returns null if not configured (e.g., in production builds)
  static String? get googleWebClientId => getOrNull('GOOGLE_WEB_CLIENT_ID');

  /// App name from environment
  static String get appName => get('APP_NAME', fallback: 'Module Tracker');

  /// App version from environment
  static String get appVersion => get('APP_VERSION', fallback: '1.0.0');
}
