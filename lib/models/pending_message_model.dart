import 'attendee_model.dart';

enum PendingMessageStatus {
  pending,
  retrying,
  sent,
  failed,
}

class PendingMessageModel {
  final int? id;
  final int serviceId;
  final int attendeeId;
  final String phoneNumber;
  final String attendeeName;
  final String messageText;
  final PendingMessageStatus status;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final int attemptCount;
  final String? lastError;

  PendingMessageModel({
    this.id,
    required this.serviceId,
    required this.attendeeId,
    required this.phoneNumber,
    required this.attendeeName,
    required this.messageText,
    this.status = PendingMessageStatus.pending,
    DateTime? createdAt,
    this.lastAttemptAt,
    this.attemptCount = 0,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'service_id': serviceId,
      'attendee_id': attendeeId,
      'phone_number': phoneNumber,
      'attendee_name': attendeeName,
      'message_text': messageText,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'attempt_count': attemptCount,
      'last_error': lastError,
    };
  }

  factory PendingMessageModel.fromMap(Map<String, dynamic> map) {
    return PendingMessageModel(
      id: map['id'] as int?,
      serviceId: map['service_id'] as int,
      attendeeId: map['attendee_id'] as int,
      phoneNumber: map['phone_number'] as String,
      attendeeName: map['attendee_name'] as String,
      messageText: map['message_text'] as String,
      status: PendingMessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => PendingMessageStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      lastAttemptAt: map['last_attempt_at'] != null
          ? DateTime.parse(map['last_attempt_at'] as String)
          : null,
      attemptCount: map['attempt_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
    );
  }

  PendingMessageModel copyWith({
    int? id,
    int? serviceId,
    int? attendeeId,
    String? phoneNumber,
    String? attendeeName,
    String? messageText,
    PendingMessageStatus? status,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    int? attemptCount,
    String? lastError,
  }) {
    return PendingMessageModel(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      attendeeId: attendeeId ?? this.attendeeId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      attendeeName: attendeeName ?? this.attendeeName,
      messageText: messageText ?? this.messageText,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
    );
  }

  bool get canRetry => attemptCount < 5 && status != PendingMessageStatus.sent;
}
