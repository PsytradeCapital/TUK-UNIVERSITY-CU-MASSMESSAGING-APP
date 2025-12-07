import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/message_log_model.dart';
import '../models/sync_queue_model.dart';
import 'message_log_repository.dart';
import 'firebase_message_log_repository.dart';
import 'sync_queue_repository.dart';
import '../services/auth_service.dart';

/// Hybrid Message Log Repository
/// Provides seamless offline/online data access by routing operations
/// to cloud when online and local database when offline
class HybridMessageLogRepository {
  final FirebaseMessageLogRepository _cloudRepo;
  final MessageLogRepository _localRepo;
  final SyncQueueRepository _syncQueueRepo;
  final AuthService _authService;
  final Connectivity _connectivity;

  HybridMessageLogRepository({
    FirebaseMessageLogRepository? cloudRepo,
    MessageLogRepository? localRepo,
    SyncQueueRepository? syncQueueRepo,
    AuthService? authService,
    Connectivity? connectivity,
  })  : _cloudRepo = cloudRepo ?? FirebaseMessageLogRepository(),
        _localRepo = localRepo ?? MessageLogRepository(),
        _syncQueueRepo = syncQueueRepo ?? SyncQueueRepository(),
        _authService = authService ?? AuthService(),
        _connectivity = connectivity ?? Connectivity();

  /// Check if device is online
  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is authenticated
  bool _isAuthenticated() {
    return _authService.getCurrentUser() != null;
  }

  /// Create message log - routes to cloud when online, local when offline
  Future<String> createMessageLog(MessageLogModel messageLog) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Online: Create in cloud and local
        try {
          final currentUser = _authService.getCurrentUser()!;
          
          // Add cloud-specific fields
          final messageLogWithCloudFields = messageLog.copyWith(
            sentBy: currentUser.uid,
            isSynced: true,
          );

          // Create in Firestore
          final firestoreId = await _cloudRepo.createMessageLog(messageLogWithCloudFields);

          // Create in local database with Firestore ID
          final localId = await _localRepo.createMessageLog(
            messageLogWithCloudFields.copyWith(firestoreId: firestoreId),
          );

          return firestoreId;
        } catch (e) {
          // If cloud creation fails, fall back to offline mode
          return await _createMessageLogOffline(messageLog);
        }
      } else {
        // Offline: Create locally and queue for sync
        return await _createMessageLogOffline(messageLog);
      }
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to create message log: $e');
    }
  }

  /// Create message log offline and queue for sync
  Future<String> _createMessageLogOffline(MessageLogModel messageLog) async {
    try {
      // Mark as not synced
      final messageLogToCreate = messageLog.copyWith(
        isSynced: false,
      );

      // Create in local database
      final localId = await _localRepo.createMessageLog(messageLogToCreate);

      // Queue for sync when online
      await _syncQueueRepo.addToQueue(SyncQueueModel(
        operation: SyncOperation.create,
        collection: 'messageLogs',
        documentId: localId.toString(),
        data: messageLogToCreate.toMap(),
        createdAt: DateTime.now(),
        status: SyncQueueStatus.pending,
      ));

      return localId.toString();
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to create message log offline: $e');
    }
  }

  /// Get message log by ID - prefers cloud when online, falls back to local
  Future<MessageLogModel?> getMessageLogById(String id) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          final cloudMessageLog = await _cloudRepo.getMessageLogById(id);
          
          if (cloudMessageLog != null) {
            // Update local cache
            if (cloudMessageLog.id != null) {
              final localMessageLog = await _localRepo.getMessageLogById(cloudMessageLog.id!);
              if (localMessageLog != null) {
                await _localRepo.updateMessageLog(cloudMessageLog.copyWith(isSynced: true));
              }
            }
            return cloudMessageLog;
          }
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      final localId = int.tryParse(id);
      if (localId != null) {
        return await _localRepo.getMessageLogById(localId);
      }

      return null;
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to get message log by ID: $e');
    }
  }

  /// Get all message logs - prefers cloud when online, falls back to local
  Future<List<MessageLogModel>> getAllMessageLogs() async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          final cloudMessageLogs = await _cloudRepo.getAllMessageLogs();
          
          // Update local cache with cloud data
          for (final cloudMessageLog in cloudMessageLogs) {
            if (cloudMessageLog.id != null) {
              final localMessageLog = await _localRepo.getMessageLogById(cloudMessageLog.id!);
              if (localMessageLog != null) {
                await _localRepo.updateMessageLog(cloudMessageLog.copyWith(isSynced: true));
              } else {
                await _localRepo.createMessageLog(cloudMessageLog.copyWith(isSynced: true));
              }
            }
          }
          
          return cloudMessageLogs;
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getAllMessageLogs();
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to get all message logs: $e');
    }
  }

  /// Get message logs by service - prefers cloud when online, falls back to local
  Future<List<MessageLogModel>> getMessageLogsByService(int serviceId) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getMessageLogsByService(serviceId);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getMessageLogsByService(serviceId);
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to get message logs by service: $e');
    }
  }

  /// Get message logs by attendee - prefers cloud when online, falls back to local
  Future<List<MessageLogModel>> getMessageLogsByAttendee(int attendeeId) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getMessageLogsByAttendee(attendeeId);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getMessageLogsByAttendee(attendeeId);
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to get message logs by attendee: $e');
    }
  }

  /// Get message logs by status - prefers cloud when online, falls back to local
  Future<List<MessageLogModel>> getMessageLogsByStatus(MessageStatus status) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getMessageLogsByStatus(status);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getMessageLogsByStatus(status);
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to get message logs by status: $e');
    }
  }

  /// Get message logs by user - prefers cloud when online, falls back to local
  Future<List<MessageLogModel>> getMessageLogsByUser(String userId) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getMessageLogsByUser(userId);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getMessageLogsByUser(userId);
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to get message logs by user: $e');
    }
  }

  /// Get message logs by date range - prefers cloud when online, falls back to local
  Future<List<MessageLogModel>> getMessageLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getMessageLogsByDateRange(startDate, endDate);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getMessageLogsByDateRange(startDate, endDate);
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to get message logs by date range: $e');
    }
  }

  /// Update message log - routes to cloud when online, local when offline
  Future<void> updateMessageLog(MessageLogModel messageLog) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Online: Update in cloud and local
        try {
          // Add cloud-specific fields
          final messageLogWithCloudFields = messageLog.copyWith(
            isSynced: true,
          );

          // Update in Firestore if it has a Firestore ID
          if (messageLogWithCloudFields.firestoreId != null) {
            await _cloudRepo.updateMessageLog(messageLogWithCloudFields);
          }

          // Update in local database
          if (messageLogWithCloudFields.id != null) {
            await _localRepo.updateMessageLog(messageLogWithCloudFields);
          }
        } catch (e) {
          // If cloud update fails, fall back to offline mode
          await _updateMessageLogOffline(messageLog);
        }
      } else {
        // Offline: Update locally and queue for sync
        await _updateMessageLogOffline(messageLog);
      }
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to update message log: $e');
    }
  }

  /// Update message log offline and queue for sync
  Future<void> _updateMessageLogOffline(MessageLogModel messageLog) async {
    try {
      if (messageLog.id == null) {
        throw HybridMessageLogRepositoryException('Cannot update message log without ID');
      }

      // Mark as not synced
      final messageLogToUpdate = messageLog.copyWith(
        isSynced: false,
      );

      // Update in local database
      await _localRepo.updateMessageLog(messageLogToUpdate);

      // Queue for sync when online
      await _syncQueueRepo.addToQueue(SyncQueueModel(
        operation: SyncOperation.update,
        collection: 'messageLogs',
        documentId: messageLog.firestoreId ?? messageLog.id.toString(),
        data: messageLogToUpdate.toMap(),
        createdAt: DateTime.now(),
        status: SyncQueueStatus.pending,
      ));
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to update message log offline: $e');
    }
  }

  /// Update message status - routes to cloud when online, local when offline
  Future<void> updateMessageStatus(String id, MessageStatus status) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Online: Update in cloud and local
        try {
          // Update in Firestore
          await _cloudRepo.updateMessageStatus(id, status);

          // Update in local database
          final localId = int.tryParse(id);
          if (localId != null) {
            await _localRepo.updateMessageStatus(localId, status);
          }
        } catch (e) {
          // If cloud update fails, fall back to offline mode
          await _updateMessageStatusOffline(id, status);
        }
      } else {
        // Offline: Update locally and queue for sync
        await _updateMessageStatusOffline(id, status);
      }
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to update message status: $e');
    }
  }

  /// Update message status offline and queue for sync
  Future<void> _updateMessageStatusOffline(String id, MessageStatus status) async {
    try {
      final localId = int.tryParse(id);
      if (localId == null) {
        throw HybridMessageLogRepositoryException('Invalid message log ID for offline update');
      }

      // Update in local database
      await _localRepo.updateMessageStatus(localId, status);

      // Get the message log to queue for sync
      final messageLog = await _localRepo.getMessageLogById(localId);
      if (messageLog != null) {
        await _syncQueueRepo.addToQueue(SyncQueueModel(
          operation: SyncOperation.update,
          collection: 'messageLogs',
          documentId: messageLog.firestoreId ?? localId.toString(),
          data: messageLog.toMap(),
          createdAt: DateTime.now(),
          status: SyncQueueStatus.pending,
        ));
      }
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to update message status offline: $e');
    }
  }

  /// Delete message log - routes to cloud when online, local when offline
  Future<void> deleteMessageLog(String id) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Online: Delete from cloud and local
        try {
          // Get message log to find both IDs
          final messageLog = await getMessageLogById(id);
          
          if (messageLog != null) {
            // Delete from Firestore if it has a Firestore ID
            if (messageLog.firestoreId != null) {
              await _cloudRepo.deleteMessageLog(messageLog.firestoreId!);
            }

            // Delete from local database
            if (messageLog.id != null) {
              await _localRepo.deleteMessageLog(messageLog.id!);
            }
          }
        } catch (e) {
          // If cloud delete fails, fall back to offline mode
          await _deleteMessageLogOffline(id);
        }
      } else {
        // Offline: Delete locally and queue for sync
        await _deleteMessageLogOffline(id);
      }
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to delete message log: $e');
    }
  }

  /// Delete message log offline and queue for sync
  Future<void> _deleteMessageLogOffline(String id) async {
    try {
      // Get message log before deleting
      final messageLog = await getMessageLogById(id);
      
      if (messageLog == null) {
        throw HybridMessageLogRepositoryException('Message log not found for deletion');
      }

      // Delete from local database
      if (messageLog.id != null) {
        await _localRepo.deleteMessageLog(messageLog.id!);
      }

      // Queue for sync when online (if it has a Firestore ID)
      if (messageLog.firestoreId != null) {
        await _syncQueueRepo.addToQueue(SyncQueueModel(
          operation: SyncOperation.delete,
          collection: 'messageLogs',
          documentId: messageLog.firestoreId!,
          data: {},
          createdAt: DateTime.now(),
          status: SyncQueueStatus.pending,
        ));
      }
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to delete message log offline: $e');
    }
  }

  /// Get message statistics - prefers cloud when online, falls back to local
  Future<MessageStatistics> getMessageStatistics() async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getMessageStatistics();
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getMessageStatistics();
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to get message statistics: $e');
    }
  }

  /// Get message statistics by service - prefers cloud when online, falls back to local
  Future<MessageStatistics> getMessageStatisticsByService(int serviceId) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getMessageStatisticsByService(serviceId);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getMessageStatisticsByService(serviceId);
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to get message statistics by service: $e');
    }
  }

  /// Get total message count - prefers cloud when online, falls back to local
  Future<int> getTotalMessageCount() async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getTotalMessageCount();
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getTotalMessageCount();
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to get total message count: $e');
    }
  }

  /// Listen to message log changes (real-time) - only works when online
  Stream<List<MessageLogModel>> messageLogsStream() {
    try {
      return _cloudRepo.messageLogsStream();
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to create message logs stream: $e');
    }
  }

  /// Listen to message logs by service (real-time) - only works when online
  Stream<List<MessageLogModel>> messageLogsByServiceStream(int serviceId) {
    try {
      return _cloudRepo.messageLogsByServiceStream(serviceId);
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to create message logs by service stream: $e');
    }
  }

  /// Batch create message logs - routes to cloud when online, local when offline
  Future<List<String>> batchCreateMessageLogs(List<MessageLogModel> messageLogs) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Online: Create in cloud and local
        try {
          final currentUser = _authService.getCurrentUser()!;
          
          // Add cloud-specific fields to all message logs
          final messageLogsWithCloudFields = messageLogs.map((ml) => ml.copyWith(
            sentBy: currentUser.uid,
            isSynced: true,
          )).toList();

          // Create in Firestore
          final firestoreIds = await _cloudRepo.batchCreateMessageLogs(messageLogsWithCloudFields);

          // Create in local database with Firestore IDs
          for (int i = 0; i < messageLogsWithCloudFields.length; i++) {
            await _localRepo.createMessageLog(
              messageLogsWithCloudFields[i].copyWith(firestoreId: firestoreIds[i]),
            );
          }

          return firestoreIds;
        } catch (e) {
          // If cloud creation fails, fall back to offline mode
          return await _batchCreateMessageLogsOffline(messageLogs);
        }
      } else {
        // Offline: Create locally and queue for sync
        return await _batchCreateMessageLogsOffline(messageLogs);
      }
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to batch create message logs: $e');
    }
  }

  /// Batch create message logs offline and queue for sync
  Future<List<String>> _batchCreateMessageLogsOffline(List<MessageLogModel> messageLogs) async {
    try {
      final List<String> localIds = [];

      for (final messageLog in messageLogs) {
        // Mark as not synced
        final messageLogToCreate = messageLog.copyWith(
          isSynced: false,
        );

        // Create in local database
        final localId = await _localRepo.createMessageLog(messageLogToCreate);
        localIds.add(localId.toString());

        // Queue for sync when online
        await _syncQueueRepo.addToQueue(SyncQueueModel(
          operation: SyncOperation.create,
          collection: 'messageLogs',
          documentId: localId.toString(),
          data: messageLogToCreate.toMap(),
          createdAt: DateTime.now(),
          status: SyncQueueStatus.pending,
        ));
      }

      return localIds;
    } catch (e) {
      throw HybridMessageLogRepositoryException('Failed to batch create message logs offline: $e');
    }
  }
}

/// Custom exception for hybrid message log repository operations
class HybridMessageLogRepositoryException implements Exception {
  final String message;

  HybridMessageLogRepositoryException(this.message);

  @override
  String toString() => 'HybridMessageLogRepositoryException: $message';
}