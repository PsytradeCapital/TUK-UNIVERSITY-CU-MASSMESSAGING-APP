import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import '../providers/app_state_provider.dart';

/// Comprehensive error handling service for the app
class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  AppStateProvider? _appStateProvider;
  final List<ErrorHandler> _errorHandlers = [];
  final StreamController<AppError> _errorStreamController = StreamController<AppError>.broadcast();

  /// Initialize error handling service
  void initialize(AppStateProvider appStateProvider) {
    _appStateProvider = appStateProvider;
    _setupDefaultErrorHandlers();
  }

  /// Get error stream for listening to errors
  Stream<AppError> get errorStream => _errorStreamController.stream;

  /// Setup default error handlers
  void _setupDefaultErrorHandlers() {
    // Database error handler
    addErrorHandler(DatabaseErrorHandler());
    
    // Network error handler
    addErrorHandler(NetworkErrorHandler());
    
    // SMS error handler
    addErrorHandler(SMSErrorHandler());
    
    // File system error handler
    addErrorHandler(FileSystemErrorHandler());
    
    // Authentication error handler
    addErrorHandler(AuthenticationErrorHandler());
    
    // Generic error handler (should be last)
    addErrorHandler(GenericErrorHandler());
  }

  /// Add custom error handler
  void addErrorHandler(ErrorHandler handler) {
    _errorHandlers.add(handler);
  }

  /// Handle error with appropriate handler
  Future<ErrorHandlingResult> handleError(
    dynamic error, 
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    final appError = AppError(
      message: error.toString(),
      context: context,
      timestamp: DateTime.now(),
      isGlobal: false,
    );

    // Add to error stream
    _errorStreamController.add(appError);

    // Try each error handler until one handles the error
    for (final handler in _errorHandlers) {
      if (handler.canHandle(error)) {
        try {
          final result = await handler.handle(error, stackTrace, context: context, metadata: metadata);
          
          // Report to app state provider if configured
          if (_appStateProvider != null && result.shouldReportToUser) {
            if (result.isGlobal) {
              _appStateProvider!.setGlobalError(result.userMessage, context: context);
            } else {
              _appStateProvider!.setScreenError(context ?? 'Unknown', result.userMessage, context: context);
            }
          }
          
          return result;
        } catch (handlerError) {
          debugPrint('Error handler failed: $handlerError');
          continue;
        }
      }
    }

    // If no handler could handle the error, use generic handling
    return ErrorHandlingResult(
      isHandled: false,
      shouldReportToUser: true,
      userMessage: 'An unexpected error occurred: ${error.toString()}',
      isGlobal: true,
      canRetry: false,
    );
  }

  /// Handle unhandled exceptions
  Future<void> handleUnhandledException(dynamic error, StackTrace stackTrace) async {
    debugPrint('Unhandled exception: $error');
    debugPrint('Stack trace: $stackTrace');
    
    await handleError(
      error, 
      stackTrace, 
      context: 'UnhandledException',
      metadata: {'isUnhandled': true},
    );
  }

  /// Dispose resources
  void dispose() {
    _errorStreamController.close();
  }
}

/// Base class for error handlers
abstract class ErrorHandler {
  /// Check if this handler can handle the given error
  bool canHandle(dynamic error);
  
  /// Handle the error and return result
  Future<ErrorHandlingResult> handle(
    dynamic error, 
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  });
}

/// Result of error handling
class ErrorHandlingResult {
  final bool isHandled;
  final bool shouldReportToUser;
  final String userMessage;
  final bool isGlobal;
  final bool canRetry;
  final VoidCallback? retryAction;
  final Map<String, dynamic>? additionalData;

  ErrorHandlingResult({
    required this.isHandled,
    required this.shouldReportToUser,
    required this.userMessage,
    required this.isGlobal,
    required this.canRetry,
    this.retryAction,
    this.additionalData,
  });
}

/// Database error handler
class DatabaseErrorHandler extends ErrorHandler {
  @override
  bool canHandle(dynamic error) {
    return error.toString().contains('database') ||
           error.toString().contains('sqlite') ||
           error.toString().contains('SQL') ||
           error.runtimeType.toString().contains('Database');
  }

  @override
  Future<ErrorHandlingResult> handle(
    dynamic error, 
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('Database error in $context: $error');
    
    String userMessage;
    bool canRetry = true;
    
    if (error.toString().contains('locked')) {
      userMessage = 'Database is temporarily locked. Please try again.';
    } else if (error.toString().contains('corrupt')) {
      userMessage = 'Database corruption detected. Please restart the app.';
      canRetry = false;
    } else if (error.toString().contains('disk')) {
      userMessage = 'Insufficient storage space. Please free up space and try again.';
    } else {
      userMessage = 'Database operation failed. Please try again.';
    }

    return ErrorHandlingResult(
      isHandled: true,
      shouldReportToUser: true,
      userMessage: userMessage,
      isGlobal: false,
      canRetry: canRetry,
    );
  }
}

/// Network error handler
class NetworkErrorHandler extends ErrorHandler {
  @override
  bool canHandle(dynamic error) {
    return error is SocketException ||
           error.toString().contains('network') ||
           error.toString().contains('connection') ||
           error.toString().contains('timeout');
  }

  @override
  Future<ErrorHandlingResult> handle(
    dynamic error, 
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('Network error in $context: $error');
    
    String userMessage;
    if (error is SocketException) {
      userMessage = 'No internet connection. Please check your network and try again.';
    } else if (error.toString().contains('timeout')) {
      userMessage = 'Connection timeout. Please try again.';
    } else {
      userMessage = 'Network error occurred. Please check your connection.';
    }

    return ErrorHandlingResult(
      isHandled: true,
      shouldReportToUser: true,
      userMessage: userMessage,
      isGlobal: false,
      canRetry: true,
    );
  }
}

/// SMS error handler
class SMSErrorHandler extends ErrorHandler {
  @override
  bool canHandle(dynamic error) {
    return error.toString().contains('SMS') ||
           error.toString().contains('telephony') ||
           error.toString().contains('message') ||
           error.toString().contains('permission');
  }

  @override
  Future<ErrorHandlingResult> handle(
    dynamic error, 
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('SMS error in $context: $error');
    
    String userMessage;
    bool canRetry = true;
    
    if (error.toString().contains('permission')) {
      userMessage = 'SMS permission required. Please grant permission in settings.';
      canRetry = false;
    } else if (error.toString().contains('credit') || error.toString().contains('balance')) {
      userMessage = 'Insufficient SMS credit. Please top up your account.';
      canRetry = false;
    } else if (error.toString().contains('network')) {
      userMessage = 'SMS sending failed due to network issues. Please try again.';
    } else {
      userMessage = 'SMS operation failed. Please try again.';
    }

    return ErrorHandlingResult(
      isHandled: true,
      shouldReportToUser: true,
      userMessage: userMessage,
      isGlobal: false,
      canRetry: canRetry,
    );
  }
}

/// File system error handler
class FileSystemErrorHandler extends ErrorHandler {
  @override
  bool canHandle(dynamic error) {
    return error is FileSystemException ||
           error.toString().contains('file') ||
           error.toString().contains('directory') ||
           error.toString().contains('path');
  }

  @override
  Future<ErrorHandlingResult> handle(
    dynamic error, 
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('File system error in $context: $error');
    
    String userMessage;
    bool canRetry = true;
    
    if (error.toString().contains('permission')) {
      userMessage = 'File access permission denied. Please check app permissions.';
      canRetry = false;
    } else if (error.toString().contains('space') || error.toString().contains('disk')) {
      userMessage = 'Insufficient storage space. Please free up space.';
      canRetry = false;
    } else if (error.toString().contains('not found')) {
      userMessage = 'File not found. The file may have been moved or deleted.';
    } else {
      userMessage = 'File operation failed. Please try again.';
    }

    return ErrorHandlingResult(
      isHandled: true,
      shouldReportToUser: true,
      userMessage: userMessage,
      isGlobal: false,
      canRetry: canRetry,
    );
  }
}

/// Authentication error handler
class AuthenticationErrorHandler extends ErrorHandler {
  @override
  bool canHandle(dynamic error) {
    return error.toString().contains('auth') ||
           error.toString().contains('pin') ||
           error.toString().contains('security') ||
           error.toString().contains('biometric');
  }

  @override
  Future<ErrorHandlingResult> handle(
    dynamic error, 
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('Authentication error in $context: $error');
    
    String userMessage;
    bool isGlobal = true;
    
    if (error.toString().contains('pin')) {
      userMessage = 'PIN authentication failed. Please try again.';
    } else if (error.toString().contains('biometric')) {
      userMessage = 'Biometric authentication failed. Please use PIN instead.';
    } else {
      userMessage = 'Authentication error. Please restart the app.';
    }

    return ErrorHandlingResult(
      isHandled: true,
      shouldReportToUser: true,
      userMessage: userMessage,
      isGlobal: isGlobal,
      canRetry: true,
    );
  }
}

/// Generic error handler (fallback)
class GenericErrorHandler extends ErrorHandler {
  @override
  bool canHandle(dynamic error) {
    return true; // Can handle any error as fallback
  }

  @override
  Future<ErrorHandlingResult> handle(
    dynamic error, 
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('Generic error in $context: $error');
    
    String userMessage = 'An unexpected error occurred. Please try again.';
    
    // Try to provide more specific messages based on error content
    if (error.toString().contains('format')) {
      userMessage = 'Invalid data format. Please check your input.';
    } else if (error.toString().contains('null')) {
      userMessage = 'Missing required data. Please try again.';
    } else if (error.toString().contains('range')) {
      userMessage = 'Value out of range. Please check your input.';
    }

    return ErrorHandlingResult(
      isHandled: true,
      shouldReportToUser: true,
      userMessage: userMessage,
      isGlobal: false,
      canRetry: true,
    );
  }
}

/// Crash reporting service (placeholder for future implementation)
class CrashReportingService {
  static final CrashReportingService _instance = CrashReportingService._internal();
  factory CrashReportingService() => _instance;
  CrashReportingService._internal();

  /// Report crash to external service (placeholder)
  Future<void> reportCrash(
    dynamic error, 
    StackTrace stackTrace, {
    Map<String, dynamic>? metadata,
  }) async {
    // In a real implementation, this would send crash reports to
    // services like Firebase Crashlytics, Sentry, etc.
    debugPrint('Crash reported: $error');
    debugPrint('Metadata: $metadata');
  }

  /// Report non-fatal error
  Future<void> reportError(
    dynamic error, 
    StackTrace? stackTrace, {
    Map<String, dynamic>? metadata,
  }) async {
    // Report non-fatal errors for monitoring
    debugPrint('Error reported: $error');
    debugPrint('Metadata: $metadata');
  }
}

/// Offline handling service
class OfflineHandlingService {
  static final OfflineHandlingService _instance = OfflineHandlingService._internal();
  factory OfflineHandlingService() => _instance;
  OfflineHandlingService._internal();

  bool _isOffline = false;
  final List<OfflineOperation> _pendingOperations = [];

  bool get isOffline => _isOffline;
  List<OfflineOperation> get pendingOperations => List.unmodifiable(_pendingOperations);

  /// Set offline status
  void setOfflineStatus(bool isOffline) {
    if (_isOffline != isOffline) {
      _isOffline = isOffline;
      debugPrint('App offline status changed: $isOffline');
      
      if (!isOffline) {
        _processPendingOperations();
      }
    }
  }

  /// Add operation to pending queue when offline
  void addPendingOperation(OfflineOperation operation) {
    _pendingOperations.add(operation);
    debugPrint('Added pending operation: ${operation.type}');
  }

  /// Process pending operations when back online
  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty) return;
    
    debugPrint('Processing ${_pendingOperations.length} pending operations');
    
    final operations = List<OfflineOperation>.from(_pendingOperations);
    _pendingOperations.clear();
    
    for (final operation in operations) {
      try {
        await operation.execute();
        debugPrint('Processed pending operation: ${operation.type}');
      } catch (e) {
        debugPrint('Failed to process pending operation: ${operation.type}, error: $e');
        // Re-add failed operations to queue
        _pendingOperations.add(operation);
      }
    }
  }

  /// Clear all pending operations
  void clearPendingOperations() {
    _pendingOperations.clear();
    debugPrint('Cleared all pending operations');
  }
}

/// Offline operation model
class OfflineOperation {
  final String type;
  final Map<String, dynamic> data;
  final Future<void> Function() execute;
  final DateTime timestamp;

  OfflineOperation({
    required this.type,
    required this.data,
    required this.execute,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}