import 'attendee_model.dart';

class ServiceModel {
  final int? serviceId;
  final String serviceName; // e.g. "Sunday Service", "Bible Study", "Cell Group"
  final DateTime serviceDate;
  final int totalAttendees;
  final bool messageSent;
  final String? messageText;
  final DateTime createdAt;
  final List<AttendeeModel> attendees;

  ServiceModel({
    this.serviceId,
    this.serviceName = 'Sunday Service',
    DateTime? serviceDate,
    this.totalAttendees = 0,
    this.messageSent = false,
    this.messageText,
    DateTime? createdAt,
    this.attendees = const [],
  }) : serviceDate = serviceDate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  // Validation method
  String? validateFields() {
    if (totalAttendees < 0) {
      return 'Total attendees cannot be negative';
    }
    
    if (messageSent && (messageText == null || messageText!.trim().isEmpty)) {
      return 'Message text is required when message is marked as sent';
    }
    
    if (messageText != null && messageText!.length > 1600) {
      return 'Message text cannot exceed 1600 characters (10 SMS limit)';
    }
    
    return null; // No validation errors
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'serviceId': serviceId,
      'serviceDate': serviceDate.toIso8601String(),
      'totalAttendees': totalAttendees,
      'messageSent': messageSent,
      'messageText': messageText,
      'createdAt': createdAt.toIso8601String(),
      'attendees': attendees.map((attendee) => attendee.toJson()).toList(),
    };
  }

  // JSON deserialization
  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      serviceId: json['serviceId'],
      serviceDate: DateTime.parse(json['serviceDate']),
      totalAttendees: json['totalAttendees'] ?? 0,
      messageSent: json['messageSent'] ?? false,
      messageText: json['messageText'],
      createdAt: DateTime.parse(json['createdAt']),
      attendees: (json['attendees'] as List<dynamic>?)
          ?.map((attendeeJson) => AttendeeModel.fromJson(attendeeJson))
          .toList() ?? [],
    );
  }

  // Database serialization (for SQLite)
  Map<String, dynamic> toMap() {
    return {
      'service_id': serviceId,
      'service_name': serviceName,
      'service_date': serviceDate.toIso8601String(),
      'total_attendees': totalAttendees,
      'message_sent': messageSent ? 1 : 0,
      'message_text': messageText,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Database deserialization (from SQLite)
  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      serviceId: map['service_id'],
      serviceName: map['service_name'] as String? ?? 'Sunday Service',
      serviceDate: DateTime.parse(map['service_date']),
      totalAttendees: map['total_attendees'] ?? 0,
      messageSent: (map['message_sent'] ?? 0) == 1,
      messageText: map['message_text'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Copy with method for updating fields
  ServiceModel copyWith({
    int? serviceId,
    String? serviceName,
    DateTime? serviceDate,
    int? totalAttendees,
    bool? messageSent,
    String? messageText,
    DateTime? createdAt,
    List<AttendeeModel>? attendees,
  }) {
    return ServiceModel(
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      serviceDate: serviceDate ?? this.serviceDate,
      totalAttendees: totalAttendees ?? this.totalAttendees,
      messageSent: messageSent ?? this.messageSent,
      messageText: messageText ?? this.messageText,
      createdAt: createdAt ?? this.createdAt,
      attendees: attendees ?? this.attendees,
    );
  }

  // Mark message as sent
  ServiceModel markMessageSent(String message) {
    return copyWith(
      messageSent: true,
      messageText: message,
    );
  }

  // Add attendee to service
  ServiceModel addAttendee(AttendeeModel attendee) {
    List<AttendeeModel> updatedAttendees = List.from(attendees);
    updatedAttendees.add(attendee);
    return copyWith(
      attendees: updatedAttendees,
      totalAttendees: updatedAttendees.length,
    );
  }

  // Remove attendee from service
  ServiceModel removeAttendee(int attendeeId) {
    List<AttendeeModel> updatedAttendees = attendees
        .where((attendee) => attendee.id != attendeeId)
        .toList();
    return copyWith(
      attendees: updatedAttendees,
      totalAttendees: updatedAttendees.length,
    );
  }

  @override
  String toString() {
    return 'ServiceModel(id: $serviceId, date: $serviceDate, attendees: $totalAttendees, messageSent: $messageSent)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceModel &&
        other.serviceId == serviceId &&
        other.serviceDate == serviceDate &&
        other.totalAttendees == totalAttendees &&
        other.messageSent == messageSent &&
        other.messageText == messageText;
  }

  @override
  int get hashCode {
    return Object.hash(serviceId, serviceDate, totalAttendees, messageSent, messageText);
  }
}