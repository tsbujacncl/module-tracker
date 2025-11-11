import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:logger/logger.dart';

/// Centralized logging service for the application
///
/// Usage:
/// ```dart
/// AppLogger.debug('Debug message');
/// AppLogger.info('Info message');
/// AppLogger.warning('Warning message');
/// AppLogger.error('Error message', error: e, stackTrace: stackTrace);
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    filter: _AppLogFilter(),
    printer: PrettyPrinter(
      methodCount: 2, // Number of method calls to be displayed
      errorMethodCount: 8, // Number of method calls if stacktrace is provided
      lineLength: 120, // Width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: _AppLogOutput(),
  );

  /// Log a debug message
  /// Only visible in debug mode
  static void debug(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an informational message
  static void info(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message
  static void warning(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.w(message, error: error, stackTrace: stackTrace);

    // Log to Crashlytics in release mode
    if (!kDebugMode && !kIsWeb) {
      FirebaseCrashlytics.instance.log('WARNING: $message');
      if (error != null) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: message,
          fatal: false,
        );
      }
    }
  }

  /// Log an error message
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.e(message, error: error, stackTrace: stackTrace);

    // Log to Crashlytics
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.log('ERROR: $message');
      if (error != null) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace ?? StackTrace.current,
          reason: message,
          fatal: false,
        );
      }
    }
  }

  /// Log a fatal error message
  static void fatal(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.f(message, error: error, stackTrace: stackTrace);

    // Log to Crashlytics as fatal
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.log('FATAL: $message');
      if (error != null) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace ?? StackTrace.current,
          reason: message,
          fatal: true,
        );
      }
    }
  }

  /// Close the logger (cleanup)
  static void close() {
    _logger.close();
  }
}

/// Custom log filter that only logs in debug mode
/// In release mode, only warnings, errors, and fatal logs are shown
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kDebugMode) {
      // In debug mode, log everything
      return true;
    } else {
      // In release mode, only log warnings and above
      return event.level.index >= Level.warning.index;
    }
  }
}

/// Custom log output
/// In debug mode, logs to console
/// In release mode, could be extended to send to crash reporting service
class _AppLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      // In debug mode, print to console
      if (kDebugMode) {
        // ignore: avoid_print
        print(line);
      }
      // In release mode, you could send to a remote logging service
      // Example: FirebaseCrashlytics.instance.log(line);
    }
  }
}
