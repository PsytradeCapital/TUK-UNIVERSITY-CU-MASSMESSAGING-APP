enum MessageStatus {
  pending,      // Message queued for sending
  sending,      // Currently being sent
  sent,         // Successfully sent to SMS provider
  delivered,    // Confirmed delivered to recipient
  failed,       // Failed to send
  cancelled     // Cancelled by user
}

class MessageLogModel {
  final int? messageId;
  final int serviceId;
  final int attendeeId;
  final String messageText;
  final MessageStatus sendStatus;
  final DateTime? sentAt;
  final String? errorMessage;
  final DateTime createdAt;

  MessageLogModel({
    this.messageId,
    required this.serviceId,
    required this.attendeeId,
    required this.messageText,
    this.sendStatus = MessageStatus.pending,
    this.sentAt,
    this.errorMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Validation method
  String? validateFields() {
    if (serviceId <= 0) {
      return 'Service ID must be positive';
    }
    
    if (attendeeId <= 0) {
      return 'Attendee ID must be positive';
    }
    
    if (messageText.trim().isEmpty) {
      return 'Message text cannot be empty';
    }
    
    if (messageText.length > 1600) {
      return 'Message text cannot exceed 1600 characters';
    }
    
    if (sendStatus == MessageStatus.sent && sentAt == null) {
      return 'Sent timestamp is required when status is sent';
    }
    
    if (sendStatus == MessageStatus.failed && (errorMessage == null || errorMessage!.trim().isEmpty)) {
      return 'Error message is required when status is failed';
    }
    
    return null; // No validation errors
  }

  // Convert MessageStatus enum to string
  static String statusToString(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return 'pending';
      case MessageStatus.sending:
        return 'sending';
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.failed:
        return 'failed';
      case MessageStatus.cancelled:
        return 'cancelled';
    }
  }

  // Convert string to MessageStatus enum
  static MessageStatus statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return MessageStatus.pending;
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'failed':
        return MessageStatus.failed;
      case 'cancelled':
        return MessageStatus.cancelled;
      default:
        return MessageStatus.pending;
    }
  }
  
  // Get user-friendly status text
  String get statusDisplayText {
    switch (sendStatus) {
      case MessageStatus.pending:
        return 'Pending';
      case MessageStatus.sending:
        return 'Sending...';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.failed:
        return 'Failed';
      case MessageStatus.cancelled:
        return 'Cancelled';
    }
  }
  
  // Get status icon
  String get statusIcon {
    switch (sendStatus) {
      case MessageStatus.pending:
        return '⏳';
      case MessageStatus.sending:
        return '📤';
      case MessageStatus.sent:
        return '✓';
      case MessageStatus.delivered:
        return '✓✓';
      case MessageStatus.failed:
        return '✗';
      case MessageStatus.cancelled:
        return '⊘';
    }
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'serviceId': serviceId,
      'attendeeId': attendeeId,
      'messageText': messageText,
      'sendStatus': statusToString(sendStatus),
      'sentAt': sentAt?.toIso8601String(),
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // JSON deserialization
  factory MessageLogModel.fromJson(Map<String, dynamic> json) {
    return MessageLogModel(
      messageId: json['messageId'],
      serviceId: json['serviceId'],
      attendeeId: json['attendeeId'],
      messageText: json['messageText'],
      sendStatus: statusFromString(json['sendStatus'] ?? 'pending'),
      sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : null,
      errorMessage: json['errorMessage'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  // Database serialization (for SQLite)
  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'service_id': serviceId,
      'attendee_id': attendeeId,
      'message_text': messageText,
      'send_status': statusToString(sendStatus),
      'sent_at': sentAt?.toIso8601String(),
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Database deserialization (from SQLite)
  factory MessageLogModel.fromMap(Map<String, dynamic> map) {
    return MessageLogModel(
      messageId: map['message_id'],
      serviceId: map['service_id'],
      attendeeId: map['attendee_id'],
      messageText: map['message_text'],
      sendStatus: statusFromString(map['send_status'] ?? 'pending'),
      sentAt: map['sent_at'] != null ? DateTime.parse(map['sent_at']) : null,
      errorMessage: map['error_message'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Copy with method for updating fields
  MessageLogModel copyWith({
    int? messageId,
    int? serviceId,
    int? attendeeId,
    String? messageText,
    MessageStatus? sendStatus,
    DateTime? sentAt,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return MessageLogModel(
      messageId: messageId ?? this.messageId,
      serviceId: serviceId ?? this.serviceId,
      attendeeId: attendeeId ?? this.attendeeId,
      messageText: messageText ?? this.messageText,
      sendStatus: sendStatus ?? this.sendStatus,
      sentAt: sentAt ?? this.sentAt,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Mark as sent
  MessageLogModel markAsSent() {
    return copyWith(
      sendStatus: MessageStatus.sent,
      sentAt: DateTime.now(),
      errorMessage: null, // Clear any previous error
    );
  }

  // Mark as failed
  MessageLogModel markAsFailed(String error) {
    return copyWith(
      sendStatus: MessageStatus.failed,
      errorMessage: error,
    );
  }

  // Mark as cancelled
  MessageLogModel markAsCancelled() {
    return copyWith(
      sendStatus: MessageStatus.cancelled,
    );
  }

  // Check if message can be retried
  bool get canRetry {
    return sendStatus == MessageStatus.failed || sendStatus == MessageStatus.cancelled;
  }

  // Check if message is completed (sent or permanently failed)
  bool get isCompleted {
    return sendStatus == MessageStatus.sent;
  }

  @override
  String toString() {
    return 'MessageLogModel(id: $messageId, serviceId: $serviceId, attendeeId: $attendeeId, status: ${statusToString(sendStatus)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageLogModel &&
        other.messageId == messageId &&
        other.serviceId == serviceId &&
        other.attendeeId == attendeeId &&
        other.messageText == messageText &&
        other.sendStatus == sendStatus;
  }

  @override
  int get hashCode {
    return Object.hash(messageId, serviceId, attendeeId, messageText, sendStatus);
  }
}