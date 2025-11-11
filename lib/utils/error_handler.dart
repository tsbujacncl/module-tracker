import 'package:firebase_auth/firebase_auth.dart';
import 'package:module_tracker/services/app_logger.dart';
import 'package:module_tracker/utils/exceptions.dart';

/// Centralized error handler for the application
///
/// Converts various error types to app-specific exceptions
/// and logs them appropriately
class ErrorHandler {
  /// Handle and convert Firebase Auth errors
  static AppException handleFirebaseAuthError(
    dynamic error, {
    StackTrace? stackTrace,
  }) {
    AppLogger.error(
      'Firebase Auth Error',
      error: error,
      stackTrace: stackTrace,
    );

    if (error is FirebaseAuthException) {
      return AuthException(
        message: error.message ?? 'Authentication failed',
        code: error.code,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return AuthException(
      message: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Handle and convert Firestore errors
  static AppException handleFirestoreError(
    dynamic error, {
    StackTrace? stackTrace,
  }) {
    AppLogger.error(
      'Firestore Error',
      error: error,
      stackTrace: stackTrace,
    );

    if (error is FirebaseException) {
      return DatabaseException(
        message: error.message ?? 'Database operation failed',
        code: error.code,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return DatabaseException(
      message: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Handle generic errors
  static AppException handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? customMessage,
  }) {
    AppLogger.error(
      customMessage ?? 'Error occurred',
      error: error,
      stackTrace: stackTrace,
    );

    // If it's already an AppException, return it
    if (error is AppException) {
      return error;
    }

    // Convert Firebase errors
    if (error is FirebaseAuthException) {
      return handleFirebaseAuthError(error, stackTrace: stackTrace);
    }
    if (error is FirebaseException) {
      return handleFirestoreError(error, stackTrace: stackTrace);
    }

    // Return generic exception
    return GenericException(
      message: customMessage ?? error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Handle network-related errors
  static NetworkException handleNetworkError(
    dynamic error, {
    StackTrace? stackTrace,
  }) {
    AppLogger.error(
      'Network Error',
      error: error,
      stackTrace: stackTrace,
    );

    String message = 'Network error occurred';
    String? code;

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('socketexception') ||
        errorString.contains('network')) {
      code = 'no-internet';
      message = 'No internet connection';
    } else if (errorString.contains('timeout')) {
      code = 'timeout';
      message = 'Request timed out';
    }

    return NetworkException(
      message: message,
      code: code,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Safely execute an async operation with error handling
  ///
  /// Usage:
  /// ```dart
  /// final result = await ErrorHandler.safely(
  ///   () async => await someAsyncOperation(),
  ///   context: 'Loading user data',
  /// );
  /// ```
  static Future<T> safely<T>(
    Future<T> Function() operation, {
    String? context,
    T Function(AppException)? onError,
  }) async {
    try {
      return await operation();
    } on AppException catch (e) {
      AppLogger.error(
        context ?? 'Operation failed',
        error: e,
        stackTrace: e.stackTrace,
      );
      if (onError != null) {
        return onError(e);
      }
      rethrow;
    } catch (error, stackTrace) {
      final appException = handleError(
        error,
        stackTrace: stackTrace,
        customMessage: context,
      );
      if (onError != null) {
        return onError(appException);
      }
      throw appException;
    }
  }

  /// Safely execute a sync operation with error handling
  ///
  /// Usage:
  /// ```dart
  /// final result = ErrorHandler.safelySync(
  ///   () => someOperation(),
  ///   context: 'Processing data',
  /// );
  /// ```
  static T safelySync<T>(
    T Function() operation, {
    String? context,
    T Function(AppException)? onError,
  }) {
    try {
      return operation();
    } on AppException catch (e) {
      AppLogger.error(
        context ?? 'Operation failed',
        error: e,
        stackTrace: e.stackTrace,
      );
      if (onError != null) {
        return onError(e);
      }
      rethrow;
    } catch (error, stackTrace) {
      final appException = handleError(
        error,
        stackTrace: stackTrace,
        customMessage: context,
      );
      if (onError != null) {
        return onError(appException);
      }
      throw appException;
    }
  }
}
