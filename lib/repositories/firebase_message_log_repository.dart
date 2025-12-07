import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_log_model.dart';

class FirebaseMessageLogRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'messageLogs';

  // Get collection reference
  CollectionReference get _messageLogsCollection => 
      _firestore.collection(_collectionName);

  // Create message log in Firestore
  Future<String> createMessageLog(MessageLogModel messageLog) async {
    try {
      final data = messageLog.toFirestore();
      
      // Create document
      final docRef = await _messageLogsCollection.add(data);
      return docRef.id;
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to create message log: $e');
    }
  }

  // Get message log by Firestore ID
  Future<MessageLogModel?> getMessageLogById(String id) async {
    try {
      final docSnapshot = await _messageLogsCollection.doc(id).get();
      
      if (!docSnapshot.exists) {
        return null;
      }
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      return MessageLogModel.fromFirestore(data, docSnapshot.id);
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to get message log by ID: $e');
    }
  }

  // Get message logs by service ID
  Future<List<MessageLogModel>> getMessageLogsByService(int serviceId) async {
    try {
      final querySnapshot = await _messageLogsCollection
          .where('serviceId', isEqualTo: serviceId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final List<MessageLogModel> messageLogs = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        messageLogs.add(MessageLogModel.fromFirestore(data, doc.id));
      }
      
      return messageLogs;
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to get message logs by service: $e');
    }
  }

  // Get all message logs from Firestore
  Future<List<MessageLogModel>> getAllMessageLogs() async {
    try {
      final querySnapshot = await _messageLogsCollection
          .orderBy('createdAt', descending: true)
          .get();
      
      final List<MessageLogModel> messageLogs = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        messageLogs.add(MessageLogModel.fromFirestore(data, doc.id));
      }
      
      return messageLogs;
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to get all message logs: $e');
    }
  }

  // Update message status in Firestore
  Future<void> updateMessageStatus(String id, MessageStatus status) async {
    try {
      await _messageLogsCollection.doc(id).update({
        'sendStatus': MessageLogModel.statusToString(status),
        'sentAt': status == MessageStatus.sent ? DateTime.now().toIso8601String() : null,
      });
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to update message status: $e');
    }
  }

  // Update full message log
  Future<void> updateMessageLog(MessageLogModel messageLog) async {
    try {
      if (messageLog.firestoreId == null) {
        throw FirebaseMessageLogRepositoryException('Cannot update message log without Firestore ID');
      }
      
      final data = messageLog.toFirestore();
      await _messageLogsCollection.doc(messageLog.firestoreId).update(data);
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to update message log: $e');
    }
  }

  // Delete message log from Firestore
  Future<void> deleteMessageLog(String id) async {
    try {
      await _messageLogsCollection.doc(id).delete();
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to delete message log: $e');
    }
  }

  // Get message statistics with aggregation
  Future<MessageStatistics> getMessageStatistics() async {
    try {
      final querySnapshot = await _messageLogsCollection.get();
      
      int totalMessages = querySnapshot.docs.length;
      int sentMessages = 0;
      int failedMessages = 0;
      int pendingMessages = 0;
      int deliveredMessages = 0;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = MessageLogModel.statusFromString(data['sendStatus'] ?? 'pending');
        
        switch (status) {
          case MessageStatus.sent:
            sentMessages++;
            break;
          case MessageStatus.failed:
            failedMessages++;
            break;
          case MessageStatus.pending:
          case MessageStatus.sending:
            pendingMessages++;
            break;
          case MessageStatus.delivered:
            deliveredMessages++;
            break;
          case MessageStatus.cancelled:
            // Don't count cancelled messages in any category
            break;
        }
      }
      
      return MessageStatistics(
        totalMessages: totalMessages,
        sentMessages: sentMessages,
        failedMessages: failedMessages,
        pendingMessages: pendingMessages,
        deliveredMessages: deliveredMessages,
      );
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to get message statistics: $e');
    }
  }

  // Get message statistics by service
  Future<MessageStatistics> getMessageStatisticsByService(int serviceId) async {
    try {
      final querySnapshot = await _messageLogsCollection
          .where('serviceId', isEqualTo: serviceId)
          .get();
      
      int totalMessages = querySnapshot.docs.length;
      int sentMessages = 0;
      int failedMessages = 0;
      int pendingMessages = 0;
      int deliveredMessages = 0;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = MessageLogModel.statusFromString(data['sendStatus'] ?? 'pending');
        
        switch (status) {
          case MessageStatus.sent:
            sentMessages++;
            break;
          case MessageStatus.failed:
            failedMessages++;
            break;
          case MessageStatus.pending:
          case MessageStatus.sending:
            pendingMessages++;
            break;
          case MessageStatus.delivered:
            deliveredMessages++;
            break;
          case MessageStatus.cancelled:
            // Don't count cancelled messages in any category
            break;
        }
      }
      
      return MessageStatistics(
        totalMessages: totalMessages,
        sentMessages: sentMessages,
        failedMessages: failedMessages,
        pendingMessages: pendingMessages,
        deliveredMessages: deliveredMessages,
      );
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to get message statistics by service: $e');
    }
  }

  // Listen to message log changes (real-time updates)
  Stream<List<MessageLogModel>> messageLogsStream() {
    try {
      return _messageLogsCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((querySnapshot) {
        final List<MessageLogModel> messageLogs = [];
        
        for (final doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          messageLogs.add(MessageLogModel.fromFirestore(data, doc.id));
        }
        
        return messageLogs;
      });
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to create message logs stream: $e');
    }
  }

  // Listen to message logs by service (real-time updates)
  Stream<List<MessageLogModel>> messageLogsByServiceStream(int serviceId) {
    try {
      return _messageLogsCollection
          .where('serviceId', isEqualTo: serviceId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((querySnapshot) {
        final List<MessageLogModel> messageLogs = [];
        
        for (final doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          messageLogs.add(MessageLogModel.fromFirestore(data, doc.id));
        }
        
        return messageLogs;
      });
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to create message logs by service stream: $e');
    }
  }

  // Get message logs by attendee ID
  Future<List<MessageLogModel>> getMessageLogsByAttendee(int attendeeId) async {
    try {
      final querySnapshot = await _messageLogsCollection
          .where('attendeeId', isEqualTo: attendeeId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final List<MessageLogModel> messageLogs = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        messageLogs.add(MessageLogModel.fromFirestore(data, doc.id));
      }
      
      return messageLogs;
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to get message logs by attendee: $e');
    }
  }

  // Get message logs by status
  Future<List<MessageLogModel>> getMessageLogsByStatus(MessageStatus status) async {
    try {
      final statusString = MessageLogModel.statusToString(status);
      final querySnapshot = await _messageLogsCollection
          .where('sendStatus', isEqualTo: statusString)
          .orderBy('createdAt', descending: true)
          .get();
      
      final List<MessageLogModel> messageLogs = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        messageLogs.add(MessageLogModel.fromFirestore(data, doc.id));
      }
      
      return messageLogs;
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to get message logs by status: $e');
    }
  }

  // Get message logs by user (sentBy)
  Future<List<MessageLogModel>> getMessageLogsByUser(String userId) async {
    try {
      final querySnapshot = await _messageLogsCollection
          .where('sentBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final List<MessageLogModel> messageLogs = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        messageLogs.add(MessageLogModel.fromFirestore(data, doc.id));
      }
      
      return messageLogs;
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to get message logs by user: $e');
    }
  }

  // Get message logs within date range
  Future<List<MessageLogModel>> getMessageLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final querySnapshot = await _messageLogsCollection
          .where('createdAt', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('createdAt', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('createdAt', descending: true)
          .get();
      
      final List<MessageLogModel> messageLogs = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        messageLogs.add(MessageLogModel.fromFirestore(data, doc.id));
      }
      
      return messageLogs;
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to get message logs by date range: $e');
    }
  }

  // Batch create message logs (for data migration)
  Future<List<String>> batchCreateMessageLogs(List<MessageLogModel> messageLogs) async {
    try {
      final batch = _firestore.batch();
      final List<String> documentIds = [];
      
      for (final messageLog in messageLogs) {
        final docRef = _messageLogsCollection.doc();
        documentIds.add(docRef.id);
        
        final data = messageLog.toFirestore();
        batch.set(docRef, data);
      }
      
      await batch.commit();
      return documentIds;
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to batch create message logs: $e');
    }
  }

  // Get total message count
  Future<int> getTotalMessageCount() async {
    try {
      final querySnapshot = await _messageLogsCollection.get();
      return querySnapshot.docs.length;
    } catch (e) {
      throw FirebaseMessageLogRepositoryException('Failed to get total message count: $e');
    }
  }
}

// Message statistics model
class MessageStatistics {
  final int totalMessages;
  final int sentMessages;
  final int failedMessages;
  final int pendingMessages;
  final int deliveredMessages;

  MessageStatistics({
    required this.totalMessages,
    required this.sentMessages,
    required this.failedMessages,
    required this.pendingMessages,
    required this.deliveredMessages,
  });

  double get successRate {
    if (totalMessages == 0) return 0.0;
    return (sentMessages + deliveredMessages) / totalMessages * 100;
  }

  double get failureRate {
    if (totalMessages == 0) return 0.0;
    return failedMessages / totalMessages * 100;
  }

  @override
  String toString() {
    return 'MessageStatistics(total: $totalMessages, sent: $sentMessages, '
           'failed: $failedMessages, pending: $pendingMessages, '
           'delivered: $deliveredMessages, successRate: ${successRate.toStringAsFixed(1)}%)';
  }
}

// Custom exception for Firebase message log repository operations
class FirebaseMessageLogRepositoryException implements Exception {
  final String message;
  
  FirebaseMessageLogRepositoryException(this.message);
  
  @override
  String toString() => 'FirebaseMessageLogRepositoryException: $message';
}
