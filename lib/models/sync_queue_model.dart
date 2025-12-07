enum SyncOperation {
  create,
  update,
  delete,
}

enum SyncQueueStatus {
  pending,
  processing,
  completed,
  failed,
}

enum SyncCollection {
  attendees,
  messageLogs,
}

class SyncQueueModel {
  final int? id;
  final String userId;
  final SyncOperation operation;
  final SyncCollection collection;
  final String? documentId; // Firestore document ID (null for create operations)
  final int? localId; // Local SQLite ID
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? processedAt;
  final SyncQueueStatus status;
  final String? errorMessage;
  final int attemptCount;

  SyncQueueModel({
    this.id,
    required this.userId,
    required this.operation,
    required this.collection,
    this.documentId,
    this.localId,
    required this.data,
    DateTime? createdAt,
    this.processedAt,
    this.status = SyncQueueStatus.pending,
    this.errorMessage,
    this.attemptCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'operation': operationToString(operation),
      'collection': collectionToString(collection),
      'document_id': documentId,
      'local_id': localId,
      'data': _encodeData(data),
      'created_at': createdAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'status': statusToString(status),
      'error_message': errorMessage,
      'attempt_count': attemptCount,
    };
  }

  // Create from SQLite map
  factory SyncQueueModel.fromMap(Map<String, dynamic> map) {
    return SyncQueueModel(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      operation: operationFromString(map['operation'] as String),
      collection: collectionFromString(map['collection'] as String),
      documentId: map['document_id'] as String?,
      localId: map['local_id'] as int?,
      data: _decodeData(map['data'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      processedAt: map['processed_at'] != null
          ? DateTime.parse(map['processed_at'] as String)
          : null,
      status: statusFromString(map['status'] as String),
      errorMessage: map['error_message'] as String?,
      attemptCount: map['attempt_count'] as int? ?? 0,
    );
  }

  // Copy with method for updates
  SyncQueueModel copyWith({
    int? id,
    String? userId,
    SyncOperation? operation,
    SyncCollection? collection,
    String? documentId,
    int? localId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? processedAt,
    SyncQueueStatus? status,
    String? errorMessage,
    int? attemptCount,
  }) {
    return SyncQueueModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      operation: operation ?? this.operation,
      collection: collection ?? this.collection,
      documentId: documentId ?? this.documentId,
      localId: localId ?? this.localId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }

  // Helper methods for enum conversion
  static String operationToString(SyncOperation operation) {
    return operation.toString().split('.').last;
  }

  static SyncOperation operationFromString(String str) {
    return SyncOperation.values.firstWhere(
      (e) => e.toString().split('.').last == str,
      orElse: () => SyncOperation.create,
    );
  }

  static String collectionToString(SyncCollection collection) {
    return collection.toString().split('.').last;
  }

  static SyncCollection collectionFromString(String str) {
    return SyncCollection.values.firstWhere(
      (e) => e.toString().split('.').last == str,
      orElse: () => SyncCollection.attendees,
    );
  }

  static String statusToString(SyncQueueStatus status) {
    return status.toString().split('.').last;
  }

  static SyncQueueStatus statusFromString(String str) {
    return SyncQueueStatus.values.firstWhere(
      (e) => e.toString().split('.').last == str,
      orElse: () => SyncQueueStatus.pending,
    );
  }

  // Encode/decode data as JSON string for SQLite storage
  static String _encodeData(Map<String, dynamic> data) {
    // Simple JSON encoding - in production, use dart:convert
    final buffer = StringBuffer('{');
    final entries = data.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('"${entry.key}":');
      if (entry.value is String) {
        buffer.write('"${entry.value}"');
      } else if (entry.value is num || entry.value is bool) {
        buffer.write('${entry.value}');
      } else if (entry.value == null) {
        buffer.write('null');
      } else {
        buffer.write('"${entry.value.toString()}"');
      }
      if (i < entries.length - 1) {
        buffer.write(',');
      }
    }
    buffer.write('}');
    return buffer.toString();
  }

  static Map<String, dynamic> _decodeData(String dataStr) {
    // Simple JSON decoding - in production, use dart:convert
    // For now, return the data as-is since we'll use proper JSON encoding
    // This is a placeholder implementation
    return {};
  }

  // Check if this queue item can be retried
  bool get canRetry => attemptCount < 5 && status == SyncQueueStatus.failed;

  @override
  String toString() {
    return 'SyncQueueModel(id: $id, operation: $operation, collection: $collection, '
           'status: $status, attempts: $attemptCount)';
  }
}
