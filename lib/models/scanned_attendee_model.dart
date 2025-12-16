import 'dart:ui';

/// Model for attendees extracted from scanned documents
class ScannedAttendee {
  final String name;
  final String phoneNumber;
  final String location;
  final double confidence; // 0.0 to 1.0
  final String sourceText; // Original text from which data was extracted
  final Rect? boundingBox; // Position in the image
  final DateTime scannedAt;
  final bool isVerified; // Whether the data has been manually verified
  final String? notes; // Additional notes or corrections

  ScannedAttendee({
    required this.name,
    required this.phoneNumber,
    required this.location,
    required this.confidence,
    required this.sourceText,
    this.boundingBox,
    DateTime? scannedAt,
    this.isVerified = false,
    this.notes,
  }) : scannedAt = scannedAt ?? DateTime.now();

  /// Create a copy with updated fields
  ScannedAttendee copyWith({
    String? name,
    String? phoneNumber,
    String? location,
    double? confidence,
    String? sourceText,
    Rect? boundingBox,
    DateTime? scannedAt,
    bool? isVerified,
    String? notes,
  }) {
    return ScannedAttendee(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      location: location ?? this.location,
      confidence: confidence ?? this.confidence,
      sourceText: sourceText ?? this.sourceText,
      boundingBox: boundingBox ?? this.boundingBox,
      scannedAt: scannedAt ?? this.scannedAt,
      isVerified: isVerified ?? this.isVerified,
      notes: notes ?? this.notes,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'location': location,
      'confidence': confidence,
      'sourceText': sourceText,
      'boundingBox': boundingBox != null ? {
        'left': boundingBox!.left,
        'top': boundingBox!.top,
        'right': boundingBox!.right,
        'bottom': boundingBox!.bottom,
      } : null,
      'scannedAt': scannedAt.toIso8601String(),
      'isVerified': isVerified,
      'notes': notes,
    };
  }

  /// Create from JSON
  factory ScannedAttendee.fromJson(Map<String, dynamic> json) {
    return ScannedAttendee(
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      location: json['location'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      sourceText: json['sourceText'] as String,
      boundingBox: json['boundingBox'] != null 
          ? Rect.fromLTRB(
              (json['boundingBox']['left'] as num).toDouble(),
              (json['boundingBox']['top'] as num).toDouble(),
              (json['boundingBox']['right'] as num).toDouble(),
              (json['boundingBox']['bottom'] as num).toDouble(),
            )
          : null,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      isVerified: json['isVerified'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  /// Convert to AttendeeModel for saving to main database
  Map<String, dynamic> toAttendeeModel({
    required int serviceId,
    String category = 'Scanned',
  }) {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'location': location,
      'yearOfStudy': null, // Not available from scanned documents
      'category': category,
      'serviceId': serviceId,
      'registeredAt': scannedAt.toIso8601String(),
      'isScanned': true,
      'scanConfidence': confidence,
      'scanSourceText': sourceText,
      'scanNotes': notes,
    };
  }

  /// Get confidence level as text
  String get confidenceLevel {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.6) return 'Medium';
    if (confidence >= 0.4) return 'Low';
    return 'Very Low';
  }

  /// Get confidence color for UI
  Color get confidenceColor {
    if (confidence >= 0.8) return const Color(0xFF4CAF50); // Green
    if (confidence >= 0.6) return const Color(0xFFFF9800); // Orange
    if (confidence >= 0.4) return const Color(0xFFF44336); // Red
    return const Color(0xFF9E9E9E); // Grey
  }

  /// Check if this attendee needs manual verification
  bool get needsVerification {
    return !isVerified && (confidence < 0.8 || name.split(' ').length < 2);
  }

  @override
  String toString() {
    return 'ScannedAttendee(name: $name, phone: $phoneNumber, location: $location, confidence: ${(confidence * 100).toInt()}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScannedAttendee && 
           other.phoneNumber == phoneNumber;
  }

  @override
  int get hashCode => phoneNumber.hashCode;
}

/// Repository for managing scanned attendees
class ScannedAttendeeRepository {
  static const String _storageKey = 'scanned_attendees';
  
  /// Save scanned attendees to local storage
  static Future<void> saveScannedAttendees(List<ScannedAttendee> attendees) async {
    // Implementation would use SharedPreferences or local database
    // For now, this is a placeholder
  }

  /// Load scanned attendees from local storage
  static Future<List<ScannedAttendee>> loadScannedAttendees() async {
    // Implementation would load from SharedPreferences or local database
    // For now, return empty list
    return [];
  }

  /// Clear all scanned attendees
  static Future<void> clearScannedAttendees() async {
    // Implementation would clear from storage
  }
}