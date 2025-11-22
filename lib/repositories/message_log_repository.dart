import 'package:sqflite/sqflite.dart';
import '../models/message_log_model.dart';
import '../services/database_manager.dart';

class MessageLogRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  // Create a new message log entry
  Future<int> createMessageLog(MessageLogModel messageLog) async {
    try {
      final db = await _databaseManager.database;
      
      final id = await db.insert(
        'message_log',
        messageLog.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      return id;
    } catch (e) {
      throw MessageLogRepositoryException('Failed to create message log: $e');
    }
  }

  // Get message log by ID
  Future<MessageLogModel?> getMessageLogById(int messageId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'message_log',
        where: 'message_id = ?',
        whereArgs: [messageId],
      );

      if (maps.isNotEmpty) {
        return MessageLogModel.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get message log by ID: $e');
    }
  }

  // Get all message logs for a service
  Future<List<MessageLogModel>> getMessageLogsByService(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'message_log',
        where: 'service_id = ?',
        whereArgs: [serviceId],
        orderBy: 'created_at ASC',
      );

      return List.generate(maps.length, (i) {
        return MessageLogModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get message logs by service: $e');
    }
  }

  // Get message logs by status
  Future<List<MessageLogModel>> getMessageLogsByStatus(MessageStatus status) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'message_log',
        where: 'send_status = ?',
        whereArgs: [MessageLogModel.statusToString(status)],
        orderBy: 'created_at DESC',
      );

      return List.generate(maps.length, (i) {
        return MessageLogModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get message logs by status: $e');
    }
  }

  // Get pending message logs for a service (for resume functionality)
  Future<List<MessageLogModel>> getPendingMessageLogs(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'message_log',
        where: 'service_id = ? AND send_status = ?',
        whereArgs: [serviceId, MessageLogModel.statusToString(MessageStatus.pending)],
        orderBy: 'created_at ASC',
      );

      return List.generate(maps.length, (i) {
        return MessageLogModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get pending message logs: $e');
    }
  }

  // Get failed message logs for a service (for retry functionality)
  Future<List<MessageLogModel>> getFailedMessageLogs(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'message_log',
        where: 'service_id = ? AND send_status = ?',
        whereArgs: [serviceId, MessageLogModel.statusToString(MessageStatus.failed)],
        orderBy: 'created_at ASC',
      );

      return List.generate(maps.length, (i) {
        return MessageLogModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get failed message logs: $e');
    }
  }

  // Update message log status
  Future<void> updateMessageLogStatus(
    int messageId, 
    MessageStatus status, {
    String? errorMessage,
    DateTime? sentAt,
  }) async {
    try {
      final db = await _databaseManager.database;
      
      final updateData = <String, dynamic>{
        'send_status': MessageLogModel.statusToString(status),
      };

      if (errorMessage != null) {
        updateData['error_message'] = errorMessage;
      }

      if (sentAt != null) {
        updateData['sent_at'] = sentAt.toIso8601String();
      } else if (status == MessageStatus.sent) {
        updateData['sent_at'] = DateTime.now().toIso8601String();
      }

      final count = await db.update(
        'message_log',
        updateData,
        where: 'message_id = ?',
        whereArgs: [messageId],
      );

      if (count == 0) {
        throw MessageLogRepositoryException('Message log not found for status update');
      }
    } catch (e) {
      throw MessageLogRepositoryException('Failed to update message log status: $e');
    }
  }

  // Mark message as sent
  Future<void> markMessageAsSent(int messageId) async {
    await updateMessageLogStatus(messageId, MessageStatus.sent);
  }

  // Mark message as failed
  Future<void> markMessageAsFailed(int messageId, String errorMessage) async {
    await updateMessageLogStatus(messageId, MessageStatus.failed, errorMessage: errorMessage);
  }

  // Mark message as cancelled
  Future<void> markMessageAsCancelled(int messageId) async {
    await updateMessageLogStatus(messageId, MessageStatus.cancelled);
  }

  // Get message logs for an attendee
  Future<List<MessageLogModel>> getMessageLogsByAttendee(int attendeeId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'message_log',
        where: 'attendee_id = ?',
        whereArgs: [attendeeId],
        orderBy: 'created_at DESC',
      );

      return List.generate(maps.length, (i) {
        return MessageLogModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get message logs by attendee: $e');
    }
  }

  // Get message logs with attendee details (JOIN query)
  Future<List<Map<String, dynamic>>> getMessageLogsWithAttendeeDetails(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT 
          ml.message_id,
          ml.service_id,
          ml.attendee_id,
          ml.message_text,
          ml.send_status,
          ml.sent_at,
          ml.error_message,
          ml.created_at,
          a.name as attendee_name,
          a.phone_number as attendee_phone,
          a.year_of_study,
          a.location
        FROM message_log ml
        INNER JOIN attendees a ON ml.attendee_id = a.id
        WHERE ml.service_id = ?
        ORDER BY ml.created_at ASC
      ''', [serviceId]);

      return maps;
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get message logs with attendee details: $e');
    }
  }

  // Get sending statistics for a service
  Future<Map<String, dynamic>> getSendingStatistics(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      // Total messages
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM message_log WHERE service_id = ?',
        [serviceId],
      );
      final totalMessages = totalResult.first['total'] as int;
      
      // Sent messages
      final sentResult = await db.rawQuery(
        'SELECT COUNT(*) as sent FROM message_log WHERE service_id = ? AND send_status = ?',
        [serviceId, MessageLogModel.statusToString(MessageStatus.sent)],
      );
      final sentMessages = sentResult.first['sent'] as int;
      
      // Failed messages
      final failedResult = await db.rawQuery(
        'SELECT COUNT(*) as failed FROM message_log WHERE service_id = ? AND send_status = ?',
        [serviceId, MessageLogModel.statusToString(MessageStatus.failed)],
      );
      final failedMessages = failedResult.first['failed'] as int;
      
      // Pending messages
      final pendingResult = await db.rawQuery(
        'SELECT COUNT(*) as pending FROM message_log WHERE service_id = ? AND send_status = ?',
        [serviceId, MessageLogModel.statusToString(MessageStatus.pending)],
      );
      final pendingMessages = pendingResult.first['pending'] as int;
      
      // Cancelled messages
      final cancelledResult = await db.rawQuery(
        'SELECT COUNT(*) as cancelled FROM message_log WHERE service_id = ? AND send_status = ?',
        [serviceId, MessageLogModel.statusToString(MessageStatus.cancelled)],
      );
      final cancelledMessages = cancelledResult.first['cancelled'] as int;

      return {
        'totalMessages': totalMessages,
        'sentMessages': sentMessages,
        'failedMessages': failedMessages,
        'pendingMessages': pendingMessages,
        'cancelledMessages': cancelledMessages,
        'successRate': totalMessages > 0 ? (sentMessages / totalMessages) * 100 : 0.0,
      };
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get sending statistics: $e');
    }
  }

  // Get overall sending statistics (across all services)
  Future<Map<String, dynamic>> getOverallSendingStatistics() async {
    try {
      final db = await _databaseManager.database;
      
      // Total messages across all services
      final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM message_log');
      final totalMessages = totalResult.first['total'] as int;
      
      // Sent messages
      final sentResult = await db.rawQuery(
        'SELECT COUNT(*) as sent FROM message_log WHERE send_status = ?',
        [MessageLogModel.statusToString(MessageStatus.sent)],
      );
      final sentMessages = sentResult.first['sent'] as int;
      
      // Failed messages
      final failedResult = await db.rawQuery(
        'SELECT COUNT(*) as failed FROM message_log WHERE send_status = ?',
        [MessageLogModel.statusToString(MessageStatus.failed)],
      );
      final failedMessages = failedResult.first['failed'] as int;
      
      // Services with messages
      final servicesResult = await db.rawQuery('SELECT COUNT(DISTINCT service_id) as services FROM message_log');
      final servicesWithMessages = servicesResult.first['services'] as int;

      return {
        'totalMessages': totalMessages,
        'sentMessages': sentMessages,
        'failedMessages': failedMessages,
        'servicesWithMessages': servicesWithMessages,
        'overallSuccessRate': totalMessages > 0 ? (sentMessages / totalMessages) * 100 : 0.0,
      };
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get overall sending statistics: $e');
    }
  }

  // Delete message logs for a service
  Future<void> deleteMessageLogsByService(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      await db.delete(
        'message_log',
        where: 'service_id = ?',
        whereArgs: [serviceId],
      );
    } catch (e) {
      throw MessageLogRepositoryException('Failed to delete message logs by service: $e');
    }
  }

  // Delete old message logs (older than specified days)
  Future<int> deleteOldMessageLogs(int daysOld) async {
    try {
      final db = await _databaseManager.database;
      
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      final count = await db.delete(
        'message_log',
        where: 'created_at < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );
      
      return count;
    } catch (e) {
      throw MessageLogRepositoryException('Failed to delete old message logs: $e');
    }
  }

  // Bulk create message logs (for batch operations)
  Future<List<int>> bulkCreateMessageLogs(List<MessageLogModel> messageLogs) async {
    try {
      final db = await _databaseManager.database;
      final List<int> insertedIds = [];
      
      await db.transaction((txn) async {
        for (final messageLog in messageLogs) {
          try {
            final id = await txn.insert(
              'message_log',
              messageLog.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            insertedIds.add(id);
          } catch (e) {
            // Continue with other message logs if one fails
            continue;
          }
        }
      });
      
      return insertedIds;
    } catch (e) {
      throw MessageLogRepositoryException('Failed to bulk create message logs: $e');
    }
  }

  // Get all message logs
  Future<List<MessageLogModel>> getAllMessageLogs() async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'message_log',
        orderBy: 'created_at DESC',
      );

      return List.generate(maps.length, (i) {
        return MessageLogModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get all message logs: $e');
    }
  }

  // Get recent message logs (for debugging/monitoring)
  Future<List<MessageLogModel>> getRecentMessageLogs({int limit = 50}) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'message_log',
        orderBy: 'created_at DESC',
        limit: limit,
      );

      return List.generate(maps.length, (i) {
        return MessageLogModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get recent message logs: $e');
    }
  }

  // Get message logs by date range
  Future<List<MessageLogModel>> getMessageLogsByDateRange(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'message_log',
        where: 'created_at >= ? AND created_at <= ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'created_at DESC',
      );

      return List.generate(maps.length, (i) {
        return MessageLogModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get message logs by date range: $e');
    }
  }

  // Check if service has any message logs
  Future<bool> serviceHasMessageLogs(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM message_log WHERE service_id = ?',
        [serviceId],
      );
      
      return (result.first['count'] as int) > 0;
    } catch (e) {
      throw MessageLogRepositoryException('Failed to check if service has message logs: $e');
    }
  }

  // Get last message log for a service
  Future<MessageLogModel?> getLastMessageLogForService(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'message_log',
        where: 'service_id = ?',
        whereArgs: [serviceId],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return MessageLogModel.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get last message log for service: $e');
    }
  }

  // Count total message logs
  Future<int> getTotalMessageLogsCount() async {
    try {
      final db = await _databaseManager.database;
      
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM message_log');
      return result.first['count'] as int;
    } catch (e) {
      throw MessageLogRepositoryException('Failed to get total message logs count: $e');
    }
  }
}

// Custom exception for message log repository operations
class MessageLogRepositoryException implements Exception {
  final String message;
  
  MessageLogRepositoryException(this.message);
  
  @override
  String toString() => 'MessageLogRepositoryException: $message';
}