import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/sync_queue_model.dart';
import '../services/database_manager.dart';

class SyncQueueRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  // Add item to sync queue
  Future<int> addToQueue(SyncQueueModel queueItem) async {
    try {
      final db = await _databaseManager.database;
      
      // Encode data as JSON string
      final map = queueItem.toMap();
      map['data'] = jsonEncode(queueItem.data);
      
      final id = await db.insert(
        'sync_queue',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      return id;
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to add to sync queue: $e');
    }
  }

  // Get all pending queue items
  Future<List<SyncQueueModel>> getPendingQueueItems() async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: [SyncQueueModel.statusToString(SyncQueueStatus.pending)],
        orderBy: 'created_at ASC',
      );

      return _mapToQueueItems(maps);
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to get pending queue items: $e');
    }
  }

  // Get queue item by ID
  Future<SyncQueueModel?> getQueueItemById(int id) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return _mapToQueueItem(maps.first);
      }
      return null;
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to get queue item by ID: $e');
    }
  }

  // Get queue items by collection
  Future<List<SyncQueueModel>> getQueueItemsByCollection(
    SyncCollection collection,
  ) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'sync_queue',
        where: 'collection = ? AND status = ?',
        whereArgs: [
          SyncQueueModel.collectionToString(collection),
          SyncQueueModel.statusToString(SyncQueueStatus.pending),
        ],
        orderBy: 'created_at ASC',
      );

      return _mapToQueueItems(maps);
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to get queue items by collection: $e');
    }
  }

  // Get queue items by user
  Future<List<SyncQueueModel>> getQueueItemsByUser(String userId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'sync_queue',
        where: 'user_id = ? AND status = ?',
        whereArgs: [
          userId,
          SyncQueueModel.statusToString(SyncQueueStatus.pending),
        ],
        orderBy: 'created_at ASC',
      );

      return _mapToQueueItems(maps);
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to get queue items by user: $e');
    }
  }

  // Update queue item status
  Future<void> updateQueueItemStatus(
    int id,
    SyncQueueStatus status, {
    String? errorMessage,
    String? documentId,
  }) async {
    try {
      final db = await _databaseManager.database;
      
      final updateData = <String, dynamic>{
        'status': SyncQueueModel.statusToString(status),
        'processed_at': DateTime.now().toIso8601String(),
      };

      if (errorMessage != null) {
        updateData['error_message'] = errorMessage;
      }

      if (documentId != null) {
        updateData['document_id'] = documentId;
      }

      // Increment attempt count if failed
      if (status == SyncQueueStatus.failed) {
        final item = await getQueueItemById(id);
        if (item != null) {
          updateData['attempt_count'] = item.attemptCount + 1;
        }
      }

      final count = await db.update(
        'sync_queue',
        updateData,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (count == 0) {
        throw SyncQueueRepositoryException('Queue item not found for status update');
      }
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to update queue item status: $e');
    }
  }

  // Mark queue item as completed
  Future<void> markAsCompleted(int id, {String? documentId}) async {
    await updateQueueItemStatus(
      id,
      SyncQueueStatus.completed,
      documentId: documentId,
    );
  }

  // Mark queue item as failed
  Future<void> markAsFailed(int id, String errorMessage) async {
    await updateQueueItemStatus(
      id,
      SyncQueueStatus.failed,
      errorMessage: errorMessage,
    );
  }

  // Mark queue item as processing
  Future<void> markAsProcessing(int id) async {
    await updateQueueItemStatus(id, SyncQueueStatus.processing);
  }

  // Retry failed queue item
  Future<void> retryQueueItem(int id) async {
    try {
      final db = await _databaseManager.database;
      
      final count = await db.update(
        'sync_queue',
        {
          'status': SyncQueueModel.statusToString(SyncQueueStatus.pending),
          'error_message': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (count == 0) {
        throw SyncQueueRepositoryException('Queue item not found for retry');
      }
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to retry queue item: $e');
    }
  }

  // Get failed queue items that can be retried
  Future<List<SyncQueueModel>> getRetryableQueueItems() async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'sync_queue',
        where: 'status = ? AND attempt_count < ?',
        whereArgs: [
          SyncQueueModel.statusToString(SyncQueueStatus.failed),
          5,
        ],
        orderBy: 'created_at ASC',
      );

      return _mapToQueueItems(maps);
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to get retryable queue items: $e');
    }
  }

  // Delete queue item
  Future<void> deleteQueueItem(int id) async {
    try {
      final db = await _databaseManager.database;
      
      final count = await db.delete(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (count == 0) {
        throw SyncQueueRepositoryException('Queue item not found for deletion');
      }
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to delete queue item: $e');
    }
  }

  // Delete completed queue items older than specified days
  Future<int> deleteOldCompletedItems(int daysOld) async {
    try {
      final db = await _databaseManager.database;
      
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      final count = await db.delete(
        'sync_queue',
        where: 'status = ? AND processed_at < ?',
        whereArgs: [
          SyncQueueModel.statusToString(SyncQueueStatus.completed),
          cutoffDate.toIso8601String(),
        ],
      );
      
      return count;
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to delete old completed items: $e');
    }
  }

  // Get queue statistics
  Future<Map<String, int>> getQueueStatistics() async {
    try {
      final db = await _databaseManager.database;
      
      // Total items
      final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM sync_queue');
      final total = totalResult.first['total'] as int;
      
      // Pending items
      final pendingResult = await db.rawQuery(
        'SELECT COUNT(*) as pending FROM sync_queue WHERE status = ?',
        [SyncQueueModel.statusToString(SyncQueueStatus.pending)],
      );
      final pending = pendingResult.first['pending'] as int;
      
      // Failed items
      final failedResult = await db.rawQuery(
        'SELECT COUNT(*) as failed FROM sync_queue WHERE status = ?',
        [SyncQueueModel.statusToString(SyncQueueStatus.failed)],
      );
      final failed = failedResult.first['failed'] as int;
      
      // Completed items
      final completedResult = await db.rawQuery(
        'SELECT COUNT(*) as completed FROM sync_queue WHERE status = ?',
        [SyncQueueModel.statusToString(SyncQueueStatus.completed)],
      );
      final completed = completedResult.first['completed'] as int;

      return {
        'total': total,
        'pending': pending,
        'failed': failed,
        'completed': completed,
      };
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to get queue statistics: $e');
    }
  }

  // Get pending count
  Future<int> getPendingCount() async {
    try {
      final db = await _databaseManager.database;
      
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE status = ?',
        [SyncQueueModel.statusToString(SyncQueueStatus.pending)],
      );
      
      return result.first['count'] as int;
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to get pending count: $e');
    }
  }

  // Clear all completed items
  Future<int> clearCompletedItems() async {
    try {
      final db = await _databaseManager.database;
      
      final count = await db.delete(
        'sync_queue',
        where: 'status = ?',
        whereArgs: [SyncQueueModel.statusToString(SyncQueueStatus.completed)],
      );
      
      return count;
    } catch (e) {
      throw SyncQueueRepositoryException('Failed to clear completed items: $e');
    }
  }

  // Helper method to convert map to queue item
  SyncQueueModel _mapToQueueItem(Map<String, dynamic> map) {
    // Decode JSON data
    final dataStr = map['data'] as String;
    final data = jsonDecode(dataStr) as Map<String, dynamic>;
    
    return SyncQueueModel(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      operation: SyncQueueModel.operationFromString(map['operation'] as String),
      collection: SyncQueueModel.collectionFromString(map['collection'] as String),
      documentId: map['document_id'] as String?,
      localId: map['local_id'] as int?,
      data: data,
      createdAt: DateTime.parse(map['created_at'] as String),
      processedAt: map['processed_at'] != null
          ? DateTime.parse(map['processed_at'] as String)
          : null,
      status: SyncQueueModel.statusFromString(map['status'] as String),
      errorMessage: map['error_message'] as String?,
      attemptCount: map['attempt_count'] as int? ?? 0,
    );
  }

  // Helper method to convert list of maps to queue items
  List<SyncQueueModel> _mapToQueueItems(List<Map<String, dynamic>> maps) {
    return maps.map((map) => _mapToQueueItem(map)).toList();
  }
}

// Custom exception for sync queue repository operations
class SyncQueueRepositoryException implements Exception {
  final String message;
  
  SyncQueueRepositoryException(this.message);
  
  @override
  String toString() => 'SyncQueueRepositoryException: $message';
}
