import 'package:flutter/foundation.dart';

class ApiConfig {
  static const baseUrl = String.fromEnvironment('API_BASE_URL');

  static String? configurationError() {
    final value = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (value.isEmpty) {
      return 'Backend URL is not configured. Build with --dart-define=API_BASE_URL=https://your-backend.example.';
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      return 'API_BASE_URL must be an absolute HTTP or HTTPS URL.';
    }
    if (kReleaseMode && uri.scheme != 'https') {
      return 'Release builds require an HTTPS backend URL.';
    }
    return null;
  }
}
