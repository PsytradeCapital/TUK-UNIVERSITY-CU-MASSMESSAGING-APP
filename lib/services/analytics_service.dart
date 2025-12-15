import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Service for handling Firebase Analytics and Crashlytics
/// Tracks user events and system errors for monitoring and improvement
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  late FirebaseAnalytics _analytics;
  late FirebaseCrashlytics _crashlytics;
  bool _initialized = false;

  /// Initialize Firebase Analytics and Crashlytics
  Future<void> initialize() async {
    if (_initialized) return;

    _analytics = FirebaseAnalytics.instance;
    _crashlytics = FirebaseCrashlytics.instance;
    
    // Enable Crashlytics collection
    await _crashlytics.setCrashlyticsCollectionEnabled(true);
    
    _initialized = true;
  }

  /// Get Firebase Analytics instance
  FirebaseAnalytics get analytics => _analytics;

  /// Get Firebase Crashlytics instance
  FirebaseCrashlytics get crashlytics => _crashlytics;

  // User Authentication Events (Requirements 8.1, 8.2)

  /// Track user login event
  Future<void> trackUserLogin({
    required String method, // 'email', 'google', etc.
    String? userId,
  }) async {
    if (!_initialized) return;

    await _analytics.logLogin(loginMethod: method);
    
    if (userId != null) {
      await _analytics.setUserId(id: userId);
    }

    await _analytics.logEvent(
      name: 'user_login_success',
      parameters: {
        'login_method': method,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Track user registration event
  Future<void> trackUserRegistration({
    required String method,
    String? userId,
  }) async {
    if (!_initialized) return;

    await _analytics.logSignUp(signUpMethod: method);
    
    if (userId != null) {
      await _analytics.setUserId(id: userId);
    }

    await _analytics.logEvent(
      name: 'user_registration',
      parameters: {
        'registration_method': method,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Track user logout event
  Future<void> trackUserLogout() async {
    if (!_initialized) return;

    await _analytics.logEvent(
      name: 'user_logout',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Attendee Registration Events (Requirements 8.1, 8.2)

  /// Track attendee registration event
  Future<void> trackAttendeeRegistration({
    required String attendeeId,
    required String location,
    required String category,
    required int serviceId,
    bool isOffline = false,
  }) async {
    if (!_initialized) return;

    await _analytics.logEvent(
      name: 'attendee_registered',
      parameters: {
        'attendee_id': attendeeId,
        'location': location,
        'category': category,
        'service_id': serviceId,
        'is_offline': isOffline,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Track attendee update event
  Future<void> trackAttendeeUpdate({
    required String attendeeId,
    required List<String> fieldsChanged,
    bool isOffline = false,
  }) async {
    if (!_initialized) return;

    await _analytics.logEvent(
      name: 'attendee_updated',
      parameters: {
        'attendee_id': attendeeId,
        'fields_changed': fieldsChanged.join(','),
        'is_offline': isOffline,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Message Sending Events (Requirements 8.1, 8.2)

  /// Track message sending event
  Future<void> trackMessageSending({
    required int recipientCount,
    required String messageType, // 'welcome', 'reminder', 'custom'
    required int serviceId,
    bool isOffline = false,
  }) async {
    if (!_initialized) return;

    await _analytics.logEvent(
      name: 'messages_sent',
      parameters: {
        'recipient_count': recipientCount,
        'message_type': messageType,
        'service_id': serviceId,
        'is_offline': isOffline,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Track message delivery status
  Future<void> trackMessageDelivery({
    required String messageId,
    required String status, // 'delivered', 'failed', 'pending'
    String? errorReason,
  }) async {
    if (!_initialized) return;

    await _analytics.logEvent(
      name: 'message_delivery_status',
      parameters: {
        'message_id': messageId,
        'status': status,
        'error_reason': errorReason ?? '',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Sync Events (Requirements 8.1, 8.2)

  /// Track sync event
  Future<void> trackSyncEvent({
    required String syncType, // 'manual', 'automatic', 'on_reconnect'
    required String direction, // 'to_cloud', 'from_cloud', 'bidirectional'
    required int itemsSynced,
    required bool success,
    String? errorMessage,
    int? durationMs,
  }) async {
    if (!_initialized) return;

    await _analytics.logEvent(
      name: 'data_sync',
      parameters: {
        'sync_type': syncType,
        'direction': direction,
        'items_synced': itemsSynced,
        'success': success,
        'error_message': errorMessage ?? '',
        'duration_ms': durationMs ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Track connectivity change
  Future<void> trackConnectivityChange({
    required bool isOnline,
    required String connectionType, // 'wifi', 'mobile', 'none'
  }) async {
    if (!_initialized) return;

    await _analytics.logEvent(
      name: 'connectivity_change',
      parameters: {
        'is_online': isOnline,
        'connection_type': connectionType,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Error Tracking (Requirements 8.3)

  /// Log non-fatal error
  Future<void> logError({
    required String error,
    required String context,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_initialized) return;

    // Log to Crashlytics
    await _crashlytics.recordError(
      error,
      stackTrace,
      reason: context,
      information: additionalData?.entries.map((e) => '${e.key}: ${e.value}').toList() ?? [],
      fatal: false,
    );

    // Log to Analytics
    await _analytics.logEvent(
      name: 'non_fatal_error',
      parameters: {
        'error_type': error.runtimeType.toString(),
        'error_message': error.toString(),
        'context': context,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalData,
      },
    );
  }

  /// Log authentication error
  Future<void> logAuthError({
    required String errorCode,
    required String errorMessage,
    String? userId,
  }) async {
    if (!_initialized) return;

    await logError(
      error: 'AuthError: $errorCode',
      context: 'Authentication',
      additionalData: {
        'error_code': errorCode,
        'error_message': errorMessage,
        'user_id': userId ?? 'unknown',
      },
    );
  }

  /// Log sync error
  Future<void> logSyncError({
    required String operation,
    required String errorMessage,
    String? collection,
    String? documentId,
  }) async {
    if (!_initialized) return;

    await logError(
      error: 'SyncError: $operation',
      context: 'Data Synchronization',
      additionalData: {
        'operation': operation,
        'error_message': errorMessage,
        'collection': collection ?? 'unknown',
        'document_id': documentId ?? 'unknown',
      },
    );
  }

  /// Log SMS error
  Future<void> logSMSError({
    required String errorMessage,
    String? phoneNumber,
    String? messageId,
  }) async {
    if (!_initialized) return;

    await logError(
      error: 'SMSError',
      context: 'SMS Sending',
      additionalData: {
        'error_message': errorMessage,
        'phone_number': phoneNumber?.replaceAll(RegExp(r'\d'), '*') ?? 'unknown', // Mask phone number
        'message_id': messageId ?? 'unknown',
      },
    );
  }

  // User Properties and Custom Dimensions

  /// Set user properties for analytics
  Future<void> setUserProperties({
    String? role,
    String? location,
    bool? isApproved,
  }) async {
    if (!_initialized) return;

    if (role != null) {
      await _analytics.setUserProperty(name: 'user_role', value: role);
    }
    
    if (location != null) {
      await _analytics.setUserProperty(name: 'user_location', value: location);
    }
    
    if (isApproved != null) {
      await _analytics.setUserProperty(name: 'is_approved', value: isApproved.toString());
    }
  }

  /// Set custom user ID for Crashlytics
  Future<void> setCrashlyticsUserId(String userId) async {
    if (!_initialized) return;

    await _crashlytics.setUserIdentifier(userId);
  }

  /// Add custom key-value pairs to crash reports
  Future<void> setCrashlyticsCustomKey(String key, String value) async {
    if (!_initialized) return;

    await _crashlytics.setCustomKey(key, value);
  }

  // Screen Tracking

  /// Track screen view
  Future<void> trackScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_initialized) return;

    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );
  }

  // Performance Monitoring

  /// Track app performance metrics
  Future<void> trackPerformance({
    required String operation,
    required int durationMs,
    bool success = true,
    String? errorMessage,
  }) async {
    if (!_initialized) return;

    await _analytics.logEvent(
      name: 'performance_metric',
      parameters: {
        'operation': operation,
        'duration_ms': durationMs,
        'success': success,
        'error_message': errorMessage ?? '',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // App Lifecycle Events

  /// Track app open event
  Future<void> trackAppOpen() async {
    if (!_initialized) return;

    await _analytics.logAppOpen();
  }

  /// Track app background event
  Future<void> trackAppBackground() async {
    if (!_initialized) return;

    await _analytics.logEvent(
      name: 'app_background',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Track app foreground event
  Future<void> trackAppForeground() async {
    if (!_initialized) return;

    await _analytics.logEvent(
      name: 'app_foreground',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Utility Methods

  /// Check if analytics is initialized
  bool get isInitialized => _initialized;

  /// Enable/disable analytics collection
  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (!_initialized) return;

    await _analytics.setAnalyticsCollectionEnabled(enabled);
  }

  /// Enable/disable crashlytics collection
  Future<void> setCrashlyticsEnabled(bool enabled) async {
    if (!_initialized) return;

    await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
  }
}