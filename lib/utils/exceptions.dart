/// Base exception class for all app-specific exceptions
///
/// All custom exceptions should extend this class
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    if (code != null) {
      return 'AppException [$code]: $message';
    }
    return 'AppException: $message';
  }

  /// User-friendly message to display in the UI
  String get userMessage => message;
}

/// Exception thrown when network operations fail
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage {
    switch (code) {
      case 'no-internet':
        return 'No internet connection. Please check your network settings.';
      case 'timeout':
        return 'Request timed out. Please try again.';
      case 'server-error':
        return 'Server error. Please try again later.';
      default:
        return 'Network error: $message';
    }
  }

  @override
  String toString() => 'NetworkException [$code]: $message';
}

/// Exception thrown when data validation fails
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code,
    this.fieldErrors,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage {
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      return fieldErrors!.values.first;
    }
    return message;
  }

  @override
  String toString() => 'ValidationException: $message';
}

/// Exception thrown when authentication operations fail
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'requires-recent-login':
        return 'Please log in again to complete this action.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      default:
        return 'Authentication error: $message';
    }
  }

  @override
  String toString() => 'AuthException [$code]: $message';
}

/// Exception thrown when database operations fail
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage {
    switch (code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'not-found':
        return 'The requested data could not be found.';
      case 'already-exists':
        return 'This data already exists.';
      case 'data-loss':
        return 'Data loss occurred. Please try again.';
      case 'unavailable':
        return 'Database is temporarily unavailable. Please try again.';
      default:
        return 'Database error: $message';
    }
  }

  @override
  String toString() => 'DatabaseException [$code]: $message';
}

/// Exception thrown when storage operations fail
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage {
    switch (code) {
      case 'quota-exceeded':
        return 'Storage quota exceeded. Please free up some space.';
      case 'unauthorized':
        return 'You do not have permission to access this file.';
      case 'not-found':
        return 'File not found.';
      default:
        return 'Storage error: $message';
    }
  }

  @override
  String toString() => 'StorageException [$code]: $message';
}

/// Exception thrown when sync operations fail
class SyncException extends AppException {
  final int? retryCount;

  const SyncException({
    required super.message,
    super.code,
    this.retryCount,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage {
    if (code == 'conflict') {
      return 'Data conflict detected. Your changes may have been overwritten.';
    }
    if (code == 'max-retries') {
      return 'Failed to sync after multiple attempts. Your data has been saved locally.';
    }
    return 'Sync error: $message';
  }

  @override
  String toString() => 'SyncException [$code]: $message';
}

/// Exception thrown when parsing data fails
class ParseException extends AppException {
  const ParseException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Failed to process data. Please try again.';

  @override
  String toString() => 'ParseException: $message';
}

/// Exception thrown when a feature is not implemented
class NotImplementedException extends AppException {
  const NotImplementedException({
    String message = 'This feature is not yet implemented',
    super.code,
  }) : super(message: message);

  @override
  String get userMessage => 'This feature is coming soon!';

  @override
  String toString() => 'NotImplementedException: $message';
}

/// Exception thrown when an operation is cancelled by the user
class CancelledException extends AppException {
  const CancelledException({
    String message = 'Operation cancelled',
    super.code,
  }) : super(message: message);

  @override
  String get userMessage => 'Operation cancelled.';

  @override
  String toString() => 'CancelledException: $message';
}

/// Generic exception for errors that don't fit other categories
class GenericException extends AppException {
  const GenericException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'An error occurred: $message';

  @override
  String toString() => 'GenericException: $message';
}
