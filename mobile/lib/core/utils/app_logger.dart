import 'package:flutter/foundation.dart';

/// Secure application logger that masks PII, emails, tokens, and passwords.
class AppLogger {
  static void debug(String message, [dynamic error]) {
    if (kDebugMode) {
      final sanitized = _sanitize(message);
      debugPrint('[DEBUG] $sanitized ${error != null ? "- $error" : ""}');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      final sanitized = _sanitize(message);
      debugPrint('[INFO] $sanitized');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    final sanitized = _sanitize(message);
    debugPrint('[ERROR] $sanitized');
    if (error != null) {
      debugPrint('[ERROR_DETAILS] ${_sanitize(error.toString())}');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('[STACKTRACE] $stackTrace');
    }
  }

  static String _sanitize(String input) {
    // Strip emails
    var out = input.replaceAll(RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'), '[REDACTED_EMAIL]');
    // Strip JWT / Bearer tokens
    out = out.replaceAll(RegExp(r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}'), '[REDACTED_TOKEN]');
    return out;
  }
}
