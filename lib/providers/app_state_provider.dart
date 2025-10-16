import 'package:flutter/foundation.dart';

/// Global app state provider for managing app-wide state and error handling
class AppStateProvider extends ChangeNotifier {
  static final AppStateProvider _instance = AppStateProvider._internal();
  factory AppStateProvider() => _instance;
  AppStateProvider._internal();

  // Loading states
  bool _isGlobalLoading = false;
  Map<String, bool> _screenLoadingStates = {};

  // Error handling
  String? _globalError;
  Map<String, String> _screenErrors = {};
  List<AppError> _errorHistory = [];

  // Navigation state
  int _currentTabIndex = 0;
  String? _currentRoute;

  // App lifecycle
  bool _isAppInForeground = true;
  DateTime? _lastActiveTime;

  // Getters
  bool get isGlobalLoading => _isGlobalLoading;
  String? get globalError => _globalError;
  int get currentTabIndex => _currentTabIndex;
  String? get currentRoute => _currentRoute;
  bool get isAppInForeground => _isAppInForeground;
  DateTime? get lastActiveTime => _lastActiveTime;
  List<AppError> get errorHistory => List.unmodifiable(_errorHistory);

  /// Set global loading state
  void setGlobalLoading(bool loading) {
    if (_isGlobalLoading != loading) {
      _isGlobalLoading = loading;
      notifyListeners();
    }
  }

  /// Set loading state for specific screen
  void setScreenLoading(String screenName, bool loading) {
    if (_screenLoadingStates[screenName] != loading) {
      _screenLoadingStates[screenName] = loading;
      notifyListeners();
    }
  }

  /// Get loading state for specific screen
  bool isScreenLoading(String screenName) {
    return _screenLoadingStates[screenName] ?? false;
  }

  /// Set global error
  void setGlobalError(String? error, {String? context}) {
    _globalError = error;
    if (error != null) {
      _addToErrorHistory(error, context: context, isGlobal: true);
    }
    notifyListeners();
  }

  /// Set error for specific screen
  void setScreenError(String screenName, String? error, {String? context}) {
    if (error != null) {
      _screenErrors[screenName] = error;
      _addToErrorHistory(error, context: context ?? screenName, isGlobal: false);
    } else {
      _screenErrors.remove(screenName);
    }
    notifyListeners();
  }

  /// Get error for specific screen
  String? getScreenError(String screenName) {
    return _screenErrors[screenName];
  }

  /// Clear all errors
  void clearAllErrors() {
    _globalError = null;
    _screenErrors.clear();
    notifyListeners();
  }

  /// Clear specific screen error
  void clearScreenError(String screenName) {
    _screenErrors.remove(screenName);
    notifyListeners();
  }

  /// Clear global error
  void clearGlobalError() {
    _globalError = null;
    notifyListeners();
  }

  /// Set current tab index
  void setCurrentTabIndex(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  /// Set current route
  void setCurrentRoute(String? route) {
    if (_currentRoute != route) {
      _currentRoute = route;
      notifyListeners();
    }
  }

  /// Update app lifecycle state
  void updateAppLifecycleState(bool isInForeground) {
    if (_isAppInForeground != isInForeground) {
      _isAppInForeground = isInForeground;
      if (!isInForeground) {
        _lastActiveTime = DateTime.now();
      }
      notifyListeners();
    }
  }

  /// Add error to history
  void _addToErrorHistory(String error, {String? context, required bool isGlobal}) {
    final appError = AppError(
      message: error,
      context: context,
      timestamp: DateTime.now(),
      isGlobal: isGlobal,
    );

    _errorHistory.insert(0, appError);
    
    // Keep only last 50 errors
    if (_errorHistory.length > 50) {
      _errorHistory = _errorHistory.take(50).toList();
    }
  }

  /// Get error summary for debugging
  Map<String, dynamic> getErrorSummary() {
    return {
      'globalError': _globalError,
      'screenErrors': Map.from(_screenErrors),
      'errorHistoryCount': _errorHistory.length,
      'recentErrors': _errorHistory.take(5).map((e) => e.toMap()).toList(),
    };
  }

  /// Handle unhandled errors
  void handleUnhandledException(dynamic error, StackTrace? stackTrace) {
    final errorMessage = 'Unhandled error: ${error.toString()}';
    debugPrint('Unhandled exception: $error');
    debugPrint('Stack trace: $stackTrace');
    
    setGlobalError(errorMessage, context: 'UnhandledException');
  }

  /// Reset app state (for testing or logout)
  void resetAppState() {
    _isGlobalLoading = false;
    _screenLoadingStates.clear();
    _globalError = null;
    _screenErrors.clear();
    _errorHistory.clear();
    _currentTabIndex = 0;
    _currentRoute = null;
    _isAppInForeground = true;
    _lastActiveTime = null;
    notifyListeners();
  }

  /// Get app state summary
  Map<String, dynamic> getAppStateSummary() {
    return {
      'isGlobalLoading': _isGlobalLoading,
      'screenLoadingStates': Map.from(_screenLoadingStates),
      'hasGlobalError': _globalError != null,
      'screenErrorCount': _screenErrors.length,
      'currentTabIndex': _currentTabIndex,
      'currentRoute': _currentRoute,
      'isAppInForeground': _isAppInForeground,
      'lastActiveTime': _lastActiveTime?.toIso8601String(),
      'errorHistoryCount': _errorHistory.length,
    };
  }
}

/// App error model for error tracking
class AppError {
  final String message;
  final String? context;
  final DateTime timestamp;
  final bool isGlobal;

  AppError({
    required this.message,
    this.context,
    required this.timestamp,
    required this.isGlobal,
  });

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'context': context,
      'timestamp': timestamp.toIso8601String(),
      'isGlobal': isGlobal,
    };
  }

  @override
  String toString() {
    return 'AppError(message: $message, context: $context, timestamp: $timestamp, isGlobal: $isGlobal)';
  }
}