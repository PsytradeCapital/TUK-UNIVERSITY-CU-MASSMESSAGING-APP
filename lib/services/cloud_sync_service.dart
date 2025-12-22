import 'dart:async';
import '../repositories/firebase_attendee_repository.dart';
import '../repositories/firebase_message_log_repository.dart';
import '../repositories/attendee_repository.dart';
import '../repositories/message_log_repository.dart';
import '../models/attendee_model.dart';
import '../models/message_log_model.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

// Sync result model
class SyncResult {
  final bool success;
  final int itemsSynced;
  final List<SyncError> errors;
  final DateTime syncedAt;

  SyncResult({
    required this.success,
    required this.itemsSynced,
    required this.errors,
    DateTime? syncedAt,
  }) : syncedAt = syncedAt ?? DateTime.now();

  @override
  String toString() {
    return 'SyncResult(success: $success, itemsSynced: $itemsSynced, '
           'errors: ${errors.length}, syncedAt: $syncedAt)';
  }
}

// Sync status model
class SyncStatus {
  final bool isSyncing;
  final bool isOnline;
  final DateTime? lastSyncAt;
  final int pendingChanges;

  SyncStatus({
    required this.isSyncing,
    required this.isOnline,
    this.lastSyncAt,
    required this.pendingChanges,
  });

  @override
  String toString() {
    return 'SyncStatus(isSyncing: $isSyncing, isOnline: $isOnline, '
           'lastSyncAt: $lastSyncAt, pendingChanges: $pendingChanges)';
  }
}

// Sync conflict model
class SyncConflict {
  final String id;
  final dynamic localData;
  final dynamic cloudData;
  final ConflictType type;

  SyncConflict({
    required this.id,
    required this.localData,
    required this.cloudData,
    required this.type,
  });

  @override
  String toString() {
    return 'SyncConflict(id: $id, type: $type)';
  }
}

// Conflict type enum
enum ConflictType {
  localNewer,
  cloudNewer,
  bothModified,
}

// Sync error model
class SyncError {
  final String message;
  final String? itemId;
  final String? itemType;
  final DateTime occurredAt;

  SyncError({
    required this.message,
    this.itemId,
    this.itemType,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();

  @override
  String toString() {
    return 'SyncError(message: $message, itemId: $itemId, itemType: $itemType)';
  }
}

// Sync event model
class SyncEvent {
  final SyncEventType type;
  final String message;
  final DateTime timestamp;
  final dynamic data;

  SyncEvent({
    required this.type,
    required this.message,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'SyncEvent(type: $type, message: $message, timestamp: $timestamp)';
  }
}

// Sync event type enum
enum SyncEventType {
  started,
  progress,
  completed,
  failed,
  conflictDetected,
}

/// Cloud Sync Service
/// Manages synchronization between local SQLite database and Cloud Firestore
class CloudSyncService {
  // Singleton pattern
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  // Repositories
  final FirebaseAttendeeRepository _firebaseAttendeeRepo = FirebaseAttendeeRepository();
  final FirebaseMessageLogRepository _firebaseMessageLogRepo = FirebaseMessageLogRepository();
  final AttendeeRepository _localAttendeeRepo = AttendeeRepository();
  final MessageLogRepository _localMessageLogRepo = MessageLogRepository();
  final AuthService _authService = AuthService();

  // Connectivity
  final ConnectivityService _connectivityService = ConnectivityService();

  // Sync state
  bool _isSyncing = false;
  DateTime? _lastSyncAt;
  bool _realTimeSyncEnabled = false;
  bool _autoSyncEnabled = true;
  
  // Stream controllers
  final StreamController<SyncEvent> _syncEventsController = 
      StreamController<SyncEvent>.broadcast();
  
  // Real-time sync subscriptions
  StreamSubscription<List<AttendeeModel>>? _attendeesStreamSubscription;
  StreamSubscription<List<MessageLogModel>>? _messageLogsStreamSubscription;
  StreamSubscription<DateTime>? _connectivitySubscription;

  /// Get sync status
  SyncStatus getSyncStatus() {
    return SyncStatus(
      isSyncing: _isSyncing,
      isOnline: _connectivityService.isOnline(),
      lastSyncAt: _lastSyncAt,
      pendingChanges: 0, // Will be calculated from local unsynced items
    );
  }

  /// Check if service is initialized
  bool get isInitialized => _authService.isAuthenticated();

  /// Sync attendees from cloud
  Future<SyncResult> syncAttendeesFromCloud() async {
    if (!_isOnline()) {
      return SyncResult(success: false, itemsSynced: 0, errors: [SyncError(message: 'No internet connection')]);
    }
    
    try {
      final cloudAttendees = await _firebaseAttendeeRepo.getAllAttendees();
      int synced = 0;
      
      for (final attendee in cloudAttendees) {
        await _localAttendeeRepo.createAttendee(attendee);
        synced++;
      }
      
      return SyncResult(success: true, itemsSynced: synced, errors: []);
    } catch (e) {
      return SyncResult(success: false, itemsSynced: 0, errors: [SyncError(message: e.toString())]);
    }
  }

  /// Sync message logs from cloud
  Future<SyncResult> syncMessageLogsFromCloud() async {
    if (!_isOnline()) {
      return SyncResult(success: false, itemsSynced: 0, errors: [SyncError(message: 'No internet connection')]);
    }
    
    try {
      final cloudLogs = await _firebaseMessageLogRepo.getAllMessageLogs();
      int synced = 0;
      
      for (final log in cloudLogs) {
        await _localMessageLogRepo.createMessageLog(log);
        synced++;
      }
      
      return SyncResult(success: true, itemsSynced: synced, errors: []);
    } catch (e) {
      return SyncResult(success: false, itemsSynced: 0, errors: [SyncError(message: e.toString())]);
    }
  }

  /// Sync services from cloud
  Future<SyncResult> syncServicesFromCloud() async {
    // For now, return empty result as services sync is not implemented
    return SyncResult(success: true, itemsSynced: 0, errors: []);
  }

  /// Check if there are pending operations
  Future<bool> hasPendingOperations() async {
    // Check for unsynced local data
    final attendees = await _localAttendeeRepo.getAllAttendees();
    final logs = await _localMessageLogRepo.getAllMessageLogs();
    
    // Simple check - in real implementation, would check sync status flags
    return attendees.isNotEmpty || logs.isNotEmpty;
  }

  /// Sync pending operations
  Future<SyncResult> syncPendingOperations() async {
    // Simply delegate to syncToCloud for now
    return await syncToCloud();
  }

  /// Check if device is online
  bool _isOnline() {
    return _connectivityService.isOnline();
  }

  /// Sync data to cloud
  Future<SyncResult> syncToCloud() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        itemsSynced: 0,
        errors: [SyncError(message: 'Sync already in progress')],
      );
    }

    _isSyncing = true;
    _emitSyncEvent(SyncEventType.started, 'Starting sync to cloud');

    final List<SyncError> errors = [];
    int itemsSynced = 0;

    try {
      // Check if online
      if (!_isOnline()) {
        throw CloudSyncException('No internet connection');
      }

      // Check if user is authenticated
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        throw CloudSyncException('User not authenticated');
      }

      // Sync attendees to cloud
      final unsyncedAttendees = await _getUnsyncedAttendees();
      _emitSyncEvent(
        SyncEventType.progress,
        'Syncing ${unsyncedAttendees.length} attendees to cloud',
      );

      for (final attendee in unsyncedAttendees) {
        try {
          // Add cloud-specific fields
          final attendeeWithCloudFields = attendee.copyWith(
            createdBy: currentUser.uid,
            createdAt: DateTime.now(),
            modifiedBy: currentUser.uid,
            modifiedAt: DateTime.now(),
          );

          // Create or update in Firestore
          if (attendee.firestoreId == null) {
            final firestoreId = await _firebaseAttendeeRepo.createAttendee(
              attendeeWithCloudFields,
            );
            
            // Update local record with Firestore ID and mark as synced
            await _localAttendeeRepo.updateAttendee(
              attendeeWithCloudFields.copyWith(
                firestoreId: firestoreId,
                isSynced: true,
              ),
            );
          } else {
            await _firebaseAttendeeRepo.updateAttendee(attendeeWithCloudFields);
            
            // Mark as synced locally
            await _localAttendeeRepo.updateAttendee(
              attendeeWithCloudFields.copyWith(isSynced: true),
            );
          }

          itemsSynced++;
        } catch (e) {
          errors.add(SyncError(
            message: 'Failed to sync attendee: $e',
            itemId: attendee.id?.toString(),
            itemType: 'attendee',
          ));
        }
      }

      // Sync message logs to cloud
      final unsyncedMessageLogs = await _getUnsyncedMessageLogs();
      _emitSyncEvent(
        SyncEventType.progress,
        'Syncing ${unsyncedMessageLogs.length} message logs to cloud',
      );

      for (final messageLog in unsyncedMessageLogs) {
        try {
          // Add cloud-specific fields
          final messageLogWithCloudFields = messageLog.copyWith(
            sentBy: currentUser.uid,
            cloudCreatedAt: DateTime.now(),
          );

          // Create or update in Firestore
          if (messageLog.firestoreId == null) {
            final firestoreId = await _firebaseMessageLogRepo.createMessageLog(
              messageLogWithCloudFields,
            );
            
            // Update local record with Firestore ID and mark as synced
            await _localMessageLogRepo.updateMessageLog(
              messageLogWithCloudFields.copyWith(
                firestoreId: firestoreId,
                isSynced: true,
              ),
            );
          } else {
            await _firebaseMessageLogRepo.updateMessageLog(messageLogWithCloudFields);
            
            // Mark as synced locally
            await _localMessageLogRepo.updateMessageLog(
              messageLogWithCloudFields.copyWith(isSynced: true),
            );
          }

          itemsSynced++;
        } catch (e) {
          errors.add(SyncError(
            message: 'Failed to sync message log: $e',
            itemId: messageLog.messageId?.toString(),
            itemType: 'messageLog',
          ));
        }
      }

      _lastSyncAt = DateTime.now();
      _emitSyncEvent(
        SyncEventType.completed,
        'Sync to cloud completed: $itemsSynced items synced',
      );

      return SyncResult(
        success: errors.isEmpty,
        itemsSynced: itemsSynced,
        errors: errors,
      );
    } catch (e) {
      _emitSyncEvent(SyncEventType.failed, 'Sync to cloud failed: $e');
      errors.add(SyncError(message: 'Sync to cloud failed: $e'));
      
      return SyncResult(
        success: false,
        itemsSynced: itemsSynced,
        errors: errors,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync data from cloud
  Future<SyncResult> syncFromCloud() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        itemsSynced: 0,
        errors: [SyncError(message: 'Sync already in progress')],
      );
    }

    _isSyncing = true;
    _emitSyncEvent(SyncEventType.started, 'Starting sync from cloud');

    final List<SyncError> errors = [];
    int itemsSynced = 0;

    try {
      // Check if online
      if (!_isOnline()) {
        throw CloudSyncException('No internet connection');
      }

      // Check if user is authenticated
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        throw CloudSyncException('User not authenticated');
      }

      // Sync attendees from cloud
      _emitSyncEvent(SyncEventType.progress, 'Syncing attendees from cloud');
      final cloudAttendees = await _firebaseAttendeeRepo.getAllAttendees();

      for (final cloudAttendee in cloudAttendees) {
        try {
          // Check if attendee exists locally
          final localAttendee = cloudAttendee.id != null
              ? await _localAttendeeRepo.getAttendeeById(cloudAttendee.id!)
              : null;

          if (localAttendee == null) {
            // Create new local record
            await _localAttendeeRepo.createAttendee(
              cloudAttendee.copyWith(isSynced: true),
            );
            itemsSynced++;
          } else {
            // Check for conflicts
            final conflict = _detectAttendeeConflict(localAttendee, cloudAttendee);
            
            if (conflict != null) {
              // Resolve conflict using last-write-wins
              final resolved = await _resolveAttendeeConflict(conflict);
              if (resolved) {
                itemsSynced++;
              }
            } else if (cloudAttendee.version > localAttendee.version) {
              // Update local record with cloud data
              await _localAttendeeRepo.updateAttendee(
                cloudAttendee.copyWith(
                  id: localAttendee.id,
                  isSynced: true,
                ),
              );
              itemsSynced++;
            }
          }
        } catch (e) {
          errors.add(SyncError(
            message: 'Failed to sync attendee from cloud: $e',
            itemId: cloudAttendee.firestoreId,
            itemType: 'attendee',
          ));
        }
      }

      // Sync message logs from cloud
      _emitSyncEvent(SyncEventType.progress, 'Syncing message logs from cloud');
      final cloudMessageLogs = await _firebaseMessageLogRepo.getAllMessageLogs();

      for (final cloudMessageLog in cloudMessageLogs) {
        try {
          // Check if message log exists locally
          final localMessageLog = cloudMessageLog.messageId != null
              ? await _localMessageLogRepo.getMessageLogById(cloudMessageLog.messageId!)
              : null;

          if (localMessageLog == null) {
            // Create new local record
            await _localMessageLogRepo.createMessageLog(
              cloudMessageLog.copyWith(isSynced: true),
            );
            itemsSynced++;
          } else {
            // Check for conflicts
            final conflict = _detectMessageLogConflict(localMessageLog, cloudMessageLog);
            
            if (conflict != null) {
              // Resolve conflict using last-write-wins
              final resolved = await _resolveMessageLogConflict(conflict);
              if (resolved) {
                itemsSynced++;
              }
            } else if (cloudMessageLog.version > localMessageLog.version) {
              // Update local record with cloud data
              await _localMessageLogRepo.updateMessageLog(
                cloudMessageLog.copyWith(
                  messageId: localMessageLog.messageId,
                  isSynced: true,
                ),
              );
              itemsSynced++;
            }
          }
        } catch (e) {
          errors.add(SyncError(
            message: 'Failed to sync message log from cloud: $e',
            itemId: cloudMessageLog.firestoreId,
            itemType: 'messageLog',
          ));
        }
      }

      _lastSyncAt = DateTime.now();
      _emitSyncEvent(
        SyncEventType.completed,
        'Sync from cloud completed: $itemsSynced items synced',
      );

      return SyncResult(
        success: errors.isEmpty,
        itemsSynced: itemsSynced,
        errors: errors,
      );
    } catch (e) {
      _emitSyncEvent(SyncEventType.failed, 'Sync from cloud failed: $e');
      errors.add(SyncError(message: 'Sync from cloud failed: $e'));
      
      return SyncResult(
        success: false,
        itemsSynced: itemsSynced,
        errors: errors,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Initialize cloud sync service
  /// Should be called once during app startup
  Future<void> initialize() async {
    // Initialize connectivity service
    await _connectivityService.initialize();
    
    // Set up auto-sync on connection restoration
    _setupAutoSync();
    
    _emitSyncEvent(SyncEventType.started, 'CloudSyncService initialized');
  }

  /// Enable auto-sync when connection is restored
  void enableAutoSync() {
    _autoSyncEnabled = true;
    _setupAutoSync();
    _emitSyncEvent(SyncEventType.started, 'Auto-sync enabled');
  }

  /// Disable auto-sync
  void disableAutoSync() {
    _autoSyncEnabled = false;
    _connectivitySubscription?.cancel();
    _emitSyncEvent(SyncEventType.completed, 'Auto-sync disabled');
  }

  /// Check if auto-sync is enabled
  bool isAutoSyncEnabled() {
    return _autoSyncEnabled;
  }

  /// Get connectivity status
  ConnectivityStatus getConnectivityStatus() {
    return _connectivityService.getConnectivityStatus();
  }

  /// Enable real-time sync
  void enableRealTimeSync() {
    if (_realTimeSyncEnabled) return;

    _realTimeSyncEnabled = true;
    _emitSyncEvent(SyncEventType.started, 'Real-time sync enabled');

    // Listen to attendees stream
    _attendeesStreamSubscription = _firebaseAttendeeRepo.attendeesStream().listen(
      (cloudAttendees) async {
        try {
          for (final cloudAttendee in cloudAttendees) {
            // Update local database with cloud changes
            final localAttendee = cloudAttendee.id != null
                ? await _localAttendeeRepo.getAttendeeById(cloudAttendee.id!)
                : null;

            if (localAttendee == null) {
              await _localAttendeeRepo.createAttendee(
                cloudAttendee.copyWith(isSynced: true),
              );
            } else if (cloudAttendee.version > localAttendee.version) {
              await _localAttendeeRepo.updateAttendee(
                cloudAttendee.copyWith(
                  id: localAttendee.id,
                  isSynced: true,
                ),
              );
            }
          }
        } catch (e) {
          _emitSyncEvent(
            SyncEventType.failed,
            'Real-time attendee sync failed: $e',
          );
        }
      },
      onError: (error) {
        _emitSyncEvent(
          SyncEventType.failed,
          'Real-time attendee sync error: $error',
        );
      },
    );

    // Listen to message logs stream
    _messageLogsStreamSubscription = _firebaseMessageLogRepo.messageLogsStream().listen(
      (cloudMessageLogs) async {
        try {
          for (final cloudMessageLog in cloudMessageLogs) {
            // Update local database with cloud changes
            final localMessageLog = cloudMessageLog.messageId != null
                ? await _localMessageLogRepo.getMessageLogById(cloudMessageLog.messageId!)
                : null;

            if (localMessageLog == null) {
              await _localMessageLogRepo.createMessageLog(
                cloudMessageLog.copyWith(isSynced: true),
              );
            } else if (cloudMessageLog.version > localMessageLog.version) {
              await _localMessageLogRepo.updateMessageLog(
                cloudMessageLog.copyWith(
                  messageId: localMessageLog.messageId,
                  isSynced: true,
                ),
              );
            }
          }
        } catch (e) {
          _emitSyncEvent(
            SyncEventType.failed,
            'Real-time message log sync failed: $e',
          );
        }
      },
      onError: (error) {
        _emitSyncEvent(
          SyncEventType.failed,
          'Real-time message log sync error: $error',
        );
      },
    );
  }

  /// Disable real-time sync
  void disableRealTimeSync() {
    if (!_realTimeSyncEnabled) return;

    _realTimeSyncEnabled = false;
    _attendeesStreamSubscription?.cancel();
    _messageLogsStreamSubscription?.cancel();
    _emitSyncEvent(SyncEventType.completed, 'Real-time sync disabled');
  }

  /// Listen to sync events
  Stream<SyncEvent> syncEvents() {
    return _syncEventsController.stream;
  }

  /// Resolve conflicts
  Future<void> resolveConflicts(List<SyncConflict> conflicts) async {
    for (final conflict in conflicts) {
      try {
        if (conflict.localData is AttendeeModel && conflict.cloudData is AttendeeModel) {
          await _resolveAttendeeConflict(conflict);
        } else if (conflict.localData is MessageLogModel && 
                   conflict.cloudData is MessageLogModel) {
          await _resolveMessageLogConflict(conflict);
        }
      } catch (e) {
        _emitSyncEvent(
          SyncEventType.failed,
          'Failed to resolve conflict for ${conflict.id}: $e',
        );
      }
    }
  }

  // Private helper methods

  /// Get unsynced attendees from local database
  Future<List<AttendeeModel>> _getUnsyncedAttendees() async {
    final allAttendees = await _localAttendeeRepo.getAllAttendees();
    return allAttendees.where((a) => !a.isSynced).toList();
  }

  /// Get unsynced message logs from local database
  Future<List<MessageLogModel>> _getUnsyncedMessageLogs() async {
    final allMessageLogs = await _localMessageLogRepo.getAllMessageLogs();
    return allMessageLogs.where((m) => !m.isSynced).toList();
  }

  /// Detect attendee conflict
  SyncConflict? _detectAttendeeConflict(
    AttendeeModel local,
    AttendeeModel cloud,
  ) {
    // Check if both have been modified
    if (local.modifiedAt != null && cloud.modifiedAt != null) {
      if (local.version == cloud.version && 
          local.lastUpdated != cloud.lastUpdated) {
        return SyncConflict(
          id: local.firestoreId ?? local.id.toString(),
          localData: local,
          cloudData: cloud,
          type: ConflictType.bothModified,
        );
      }
    }

    // Check if local is newer
    if (local.modifiedAt != null && cloud.modifiedAt != null) {
      if (local.modifiedAt!.isAfter(cloud.modifiedAt!)) {
        return SyncConflict(
          id: local.firestoreId ?? local.id.toString(),
          localData: local,
          cloudData: cloud,
          type: ConflictType.localNewer,
        );
      }
    }

    // Check if cloud is newer
    if (cloud.modifiedAt != null && local.modifiedAt != null) {
      if (cloud.modifiedAt!.isAfter(local.modifiedAt!)) {
        return SyncConflict(
          id: local.firestoreId ?? local.id.toString(),
          localData: local,
          cloudData: cloud,
          type: ConflictType.cloudNewer,
        );
      }
    }

    return null;
  }

  /// Detect message log conflict
  SyncConflict? _detectMessageLogConflict(
    MessageLogModel local,
    MessageLogModel cloud,
  ) {
    // Check if both have been modified
    if (local.version == cloud.version && 
        local.createdAt != cloud.createdAt) {
      return SyncConflict(
        id: local.firestoreId ?? local.messageId.toString(),
        localData: local,
        cloudData: cloud,
        type: ConflictType.bothModified,
      );
    }

    return null;
  }

  /// Resolve attendee conflict using last-write-wins strategy
  Future<bool> _resolveAttendeeConflict(SyncConflict conflict) async {
    try {
      final local = conflict.localData as AttendeeModel;
      final cloud = conflict.cloudData as AttendeeModel;

      _emitSyncEvent(
        SyncEventType.conflictDetected,
        'Conflict detected for attendee ${conflict.id}',
        data: conflict,
      );

      // Last-write-wins: use the one with the latest modification time
      AttendeeModel winner;
      
      if (conflict.type == ConflictType.cloudNewer) {
        winner = cloud;
      } else if (conflict.type == ConflictType.localNewer) {
        winner = local;
      } else {
        // Both modified: use the one with latest timestamp
        if (local.modifiedAt != null && cloud.modifiedAt != null) {
          winner = local.modifiedAt!.isAfter(cloud.modifiedAt!) ? local : cloud;
        } else {
          winner = cloud; // Default to cloud if timestamps are missing
        }
      }

      // Increment version number
      final resolved = winner.copyWith(version: winner.version + 1);

      // Update both local and cloud with the winner
      if (local.id != null) {
        await _localAttendeeRepo.updateAttendee(
          resolved.copyWith(id: local.id, isSynced: true),
        );
      }
      
      if (resolved.firestoreId != null) {
        await _firebaseAttendeeRepo.updateAttendee(resolved);
      }

      return true;
    } catch (e) {
      _emitSyncEvent(
        SyncEventType.failed,
        'Failed to resolve attendee conflict: $e',
      );
      return false;
    }
  }

  /// Resolve message log conflict using last-write-wins strategy
  Future<bool> _resolveMessageLogConflict(SyncConflict conflict) async {
    try {
      final local = conflict.localData as MessageLogModel;
      final cloud = conflict.cloudData as MessageLogModel;

      _emitSyncEvent(
        SyncEventType.conflictDetected,
        'Conflict detected for message log ${conflict.id}',
        data: conflict,
      );

      // Last-write-wins: use cloud data as source of truth for message logs
      final resolved = cloud.copyWith(version: cloud.version + 1);

      // Update local with cloud data
      if (local.messageId != null) {
        await _localMessageLogRepo.updateMessageLog(
          resolved.copyWith(messageId: local.messageId, isSynced: true),
        );
      }

      return true;
    } catch (e) {
      _emitSyncEvent(
        SyncEventType.failed,
        'Failed to resolve message log conflict: $e',
      );
      return false;
    }
  }

  /// Emit sync event
  void _emitSyncEvent(SyncEventType type, String message, {dynamic data}) {
    _syncEventsController.add(SyncEvent(
      type: type,
      message: message,
      data: data,
    ));
  }

  /// Set up auto-sync on connection restoration
  void _setupAutoSync() {
    if (!_autoSyncEnabled) return;

    // Cancel existing subscription
    _connectivitySubscription?.cancel();

    // Listen for connection restoration
    _connectivitySubscription = _connectivityService.connectionRestoredStream().listen((restoredAt) async {
        _emitSyncEvent(
          SyncEventType.started,
          'Connection restored at $restoredAt - triggering auto-sync',
        );

        try {
          // Wait a moment for connection to stabilize
          await Future.delayed(const Duration(seconds: 2));

          // Check if still online and authenticated
          if (_connectivityService.isOnline() && _authService.isAuthenticated()) {
            // Trigger bidirectional sync
            await syncFromCloud();
            await syncToCloud();
            
            _emitSyncEvent(
              SyncEventType.completed,
              'Auto-sync completed after connection restoration',
            );
          }
        } catch (e) {
          _emitSyncEvent(
            SyncEventType.failed,
            'Auto-sync failed after connection restoration: $e',
          );
        }
      },
      onError: (error) {
        _emitSyncEvent(
          SyncEventType.failed,
          'Auto-sync connection monitoring error: $error',
        );
      },
    );
  }

  /// Dispose resources
  void dispose() {
    disableRealTimeSync();
    disableAutoSync();
    _syncEventsController.close();
    _connectivityService.dispose();
  }
}

// Custom exception for cloud sync operations
class CloudSyncException implements Exception {
  final String message;
  
  CloudSyncException(this.message);
  
  @override
  String toString() => 'CloudSyncException: $message';
}
