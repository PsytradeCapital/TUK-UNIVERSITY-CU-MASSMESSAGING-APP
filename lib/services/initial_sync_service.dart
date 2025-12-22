import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_sync_service.dart';
import 'connectivity_service.dart';
import 'analytics_service.dart';
import 'auth_service.dart';

/// Service for handling initial data synchronization on first login
/// Requirements 2.2, 4.3 - Sync data from cloud on first login and handle sync errors
class InitialSyncService {
  static final InitialSyncService _instance = InitialSyncService._internal();
  factory InitialSyncService() => _instance;
  InitialSyncService._internal();

  final CloudSyncService _cloudSyncService = CloudSyncService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final AuthService _authService = AuthService();

  static const String _firstSyncCompleteKey = 'first_sync_complete';
  static const String _lastSyncUserKey = 'last_sync_user';

  /// Check if initial sync is needed for current user
  Future<bool> needsInitialSync() async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final lastSyncUser = prefs.getString(_lastSyncUserKey);
      final firstSyncComplete = prefs.getBool(_firstSyncCompleteKey) ?? false;

      // Need initial sync if:
      // 1. First sync never completed, OR
      // 2. Different user is logged in
      return !firstSyncComplete || lastSyncUser != currentUser.uid;
    } catch (e) {
      debugPrint('Error checking initial sync status: $e');
      return true; // Default to needing sync if we can't determine
    }
  }

  /// Perform initial data synchronization
  Future<InitialSyncResult> performInitialSync({
    Function(String)? onStatusUpdate,
    Function(double)? onProgressUpdate,
  }) async {
    final startTime = DateTime.now();
    
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      onStatusUpdate?.call('Checking connectivity...');
      onProgressUpdate?.call(0.1);

      // Check connectivity
      final isOnline = await _connectivityService.isOnline();
      if (!isOnline) {
        return InitialSyncResult(
          success: false,
          error: 'No internet connection available',
          canRetry: true,
          offlineMode: true,
        );
      }

      onStatusUpdate?.call('Initializing sync service...');
      onProgressUpdate?.call(0.2);

      // Initialize cloud sync service if not already done
      if (!_cloudSyncService.isInitialized) {
        await _cloudSyncService.initialize();
      }

      onStatusUpdate?.call('Syncing attendee data...');
      onProgressUpdate?.call(0.3);

      // Sync attendees from cloud
      final attendeeResult = await _cloudSyncService.syncAttendeesFromCloud();
      if (!attendeeResult.success) {
        throw Exception('Failed to sync attendees: ${attendeeResult.errors.isNotEmpty ? attendeeResult.errors.first.message : "Unknown error"}');
      }

      onStatusUpdate?.call('Syncing message history...');
      onProgressUpdate?.call(0.6);

      // Sync message logs from cloud
      final messageResult = await _cloudSyncService.syncMessageLogsFromCloud();
      if (!messageResult.success) {
        throw Exception('Failed to sync messages: ${messageResult.errors.isNotEmpty ? messageResult.errors.first.message : "Unknown error"}');
      }

      onStatusUpdate?.call('Syncing services data...');
      onProgressUpdate?.call(0.8);

      // Sync services data from cloud
      final servicesResult = await _cloudSyncService.syncServicesFromCloud();
      if (!servicesResult.success) {
        throw Exception('Failed to sync services: ${servicesResult.errors.isNotEmpty ? servicesResult.errors.first.message : "Unknown error"}');
      }

      onStatusUpdate?.call('Finalizing sync...');
      onProgressUpdate?.call(0.9);

      // Mark initial sync as complete for this user
      await _markInitialSyncComplete(currentUser.uid);

      onStatusUpdate?.call('Sync completed successfully');
      onProgressUpdate?.call(1.0);

      final duration = DateTime.now().difference(startTime);

      // Track successful sync
      await _analyticsService.trackSyncEvent(
        syncType: 'initial',
        direction: 'from_cloud',
        itemsSynced: attendeeResult.itemsSynced + messageResult.itemsSynced + servicesResult.itemsSynced,
        success: true,
        durationMs: duration.inMilliseconds,
      );

      return InitialSyncResult(
        success: true,
        itemsSynced: attendeeResult.itemsSynced + messageResult.itemsSynced + servicesResult.itemsSynced,
        duration: duration,
      );

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      debugPrint('Initial sync failed: $e');

      // Track failed sync
      await _analyticsService.trackSyncEvent(
        syncType: 'initial',
        direction: 'from_cloud',
        itemsSynced: 0,
        success: false,
        errorMessage: e.toString(),
        durationMs: duration.inMilliseconds,
      );

      // Log sync error
      await _analyticsService.logSyncError(
        operation: 'initial_sync',
        errorMessage: e.toString(),
      );

      return InitialSyncResult(
        success: false,
        error: e.toString(),
        canRetry: true,
        duration: duration,
      );
    }
  }

  /// Mark initial sync as complete for the given user
  Future<void> _markInitialSyncComplete(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstSyncCompleteKey, true);
      await prefs.setString(_lastSyncUserKey, userId);
      await prefs.setString('last_initial_sync_time', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error marking initial sync complete: $e');
    }
  }

  /// Reset initial sync status (for testing or troubleshooting)
  Future<void> resetInitialSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_firstSyncCompleteKey);
      await prefs.remove(_lastSyncUserKey);
      await prefs.remove('last_initial_sync_time');
    } catch (e) {
      debugPrint('Error resetting initial sync status: $e');
    }
  }

  /// Get last initial sync time
  Future<DateTime?> getLastInitialSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString('last_initial_sync_time');
      if (timeString != null) {
        return DateTime.parse(timeString);
      }
    } catch (e) {
      debugPrint('Error getting last initial sync time: $e');
    }
    return null;
  }

  /// Check if user has changed since last sync
  Future<bool> hasUserChanged() async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final lastSyncUser = prefs.getString(_lastSyncUserKey);
      
      return lastSyncUser != currentUser.uid;
    } catch (e) {
      debugPrint('Error checking user change: $e');
      return true; // Default to assuming user changed
    }
  }

  /// Perform lightweight sync check (for app resume)
  Future<bool> performLightweightSync() async {
    try {
      final isOnline = await _connectivityService.isOnline();
      if (!isOnline) return false;

      // Just check if there are any pending sync operations
      final hasPendingOperations = await _cloudSyncService.hasPendingOperations();
      
      if (hasPendingOperations) {
        // Perform a quick sync of pending operations only
        final result = await _cloudSyncService.syncPendingOperations();
        
        await _analyticsService.trackSyncEvent(
          syncType: 'lightweight',
          direction: 'bidirectional',
          itemsSynced: result.itemsSynced,
          success: result.success,
          errorMessage: result.errors.isNotEmpty ? result.errors.first.message : "Unknown error",
        );
        
        return result.success;
      }
      
      return true; // No pending operations, consider successful
    } catch (e) {
      debugPrint('Lightweight sync failed: $e');
      return false;
    }
  }
}

/// Result of initial synchronization
class InitialSyncResult {
  final bool success;
  final String? error;
  final bool canRetry;
  final bool offlineMode;
  final int itemsSynced;
  final Duration? duration;

  InitialSyncResult({
    required this.success,
    this.error,
    this.canRetry = false,
    this.offlineMode = false,
    this.itemsSynced = 0,
    this.duration,
  });

  @override
  String toString() {
    return 'InitialSyncResult(success: $success, error: $error, itemsSynced: $itemsSynced, duration: ${duration?.inMilliseconds}ms)';
  }
}

/// Initial sync progress callback
typedef InitialSyncProgressCallback = void Function(String status, double progress);

/// Initial sync status
enum InitialSyncStatus {
  notStarted,
  inProgress,
  completed,
  failed,
  offline,
}