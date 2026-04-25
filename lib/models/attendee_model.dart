enum AttendeeCategory {
  student,
  associate,
  visitor
}

class AttendeeModel {
  final int? id; // Local SQLite ID
  final String name;
  final String phoneNumber;
  final String yearOfStudy;
  final String location;
  final AttendeeCategory category;
  final int attendanceCount;
  final DateTime firstRegistered;
  final DateTime lastUpdated;
  
  // Cloud sync fields
  final String? firestoreId; // Firestore document ID
  final String? createdBy; // User UID who created
  final DateTime? createdAt; // Cloud timestamp
  final String? modifiedBy; // User UID who last modified
  final DateTime? modifiedAt; // Last modification timestamp
  final bool isSynced; // Sync status
  final int version; // For conflict resolution

  AttendeeModel({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.yearOfStudy,
    required this.location,
    this.category = AttendeeCategory.student,
    this.attendanceCount = 0,
    DateTime? firstRegistered,
    DateTime? lastUpdated,
    this.firestoreId,
    this.createdBy,
    this.createdAt,
    this.modifiedBy,
    this.modifiedAt,
    this.isSynced = false,
    this.version = 1,
  }) : firstRegistered = firstRegistered ?? DateTime.now(),
       lastUpdated = lastUpdated ?? DateTime.now();

  // Phone number validation for Kenyan formats
  // Accepts: 07xxxxxxxx, 01xxxxxxxx, +2547xxxxxxxx, +2541xxxxxxxx
  static bool isValidKenyanPhone(String phone) {
    phone = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) return false;

    // +254 format: +254 followed by 9 digits starting with 7 or 1
    if (phone.startsWith('+254')) {
      final digits = phone.substring(4);
      return digits.length == 9 && RegExp(r'^[71]\d{8}$').hasMatch(digits);
    }

    // 07xxxxxxxx or 01xxxxxxxx: exactly 10 digits
    if (phone.startsWith('07') || phone.startsWith('01')) {
      return phone.length == 10 && RegExp(r'^0[71]\d{8}$').hasMatch(phone);
    }

    return false;
  }

  // Normalize phone number to consistent format.
  // Stores as 07xxxxxxxx / 01xxxxxxxx (local format) for SMS compatibility.
  static String normalizePhoneNumber(String phone) {
    phone = phone.trim().replaceAll(RegExp(r'\s+'), '');

    // +254xxxxxxxxx → 0xxxxxxxxx
    if (phone.startsWith('+254') && phone.length == 13) {
      return '0${phone.substring(4)}';
    }

    // Already in 07/01 format
    if (phone.startsWith('07') || phone.startsWith('01')) {
      return phone;
    }

    // 254xxxxxxxxx (no +) → 0xxxxxxxxx
    if (phone.startsWith('254') && phone.length == 12) {
      return '0${phone.substring(3)}';
    }

    return phone; // Return as-is if format not recognized
  }

  // Mask phone number for display (e.g., 0712****56)
  static String maskPhoneNumber(String phone) {
    if (phone.length < 4) return phone;

    if (phone.startsWith('+254') && phone.length >= 13) {
      return '${phone.substring(0, 7)}****${phone.substring(phone.length - 2)}';
    } else if ((phone.startsWith('07') || phone.startsWith('01')) && phone.length >= 10) {
      return '${phone.substring(0, 4)}****${phone.substring(phone.length - 2)}';
    }

    if (phone.length >= 6) {
      return '${phone.substring(0, 3)}****${phone.substring(phone.length - 2)}';
    }

    return phone;
  }

  // Convert category enum to string
  static String categoryToString(AttendeeCategory category) {
    switch (category) {
      case AttendeeCategory.student:
        return 'student';
      case AttendeeCategory.associate:
        return 'associate';
      case AttendeeCategory.visitor:
        return 'visitor';
    }
  }

  // Convert string to category enum
  static AttendeeCategory categoryFromString(String category) {
    switch (category.toLowerCase()) {
      case 'student':
        return AttendeeCategory.student;
      case 'associate':
        return AttendeeCategory.associate;
      case 'visitor':
        return AttendeeCategory.visitor;
      default:
        return AttendeeCategory.student;
    }
  }

  // Get category display name
  String get categoryDisplayName {
    switch (category) {
      case AttendeeCategory.student:
        return 'Student';
      case AttendeeCategory.associate:
        return 'Associate';
      case AttendeeCategory.visitor:
        return 'Visitor';
    }
  }

  // Validation method
  String? validateFields() {
    if (name.trim().isEmpty) {
      return 'Name cannot be empty';
    }

    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }

    if (!isValidKenyanPhone(phoneNumber)) {
      return 'Invalid phone number format. Use 07xxxxxxxx, 01xxxxxxxx, or +254xxxxxxxxx';
    }

    // Year of study is required only for students
    if (category == AttendeeCategory.student) {
      if (yearOfStudy.isEmpty) {
        return 'Year of study is required for students';
      }

      const validYears = ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year', '6th Year'];
      if (!validYears.contains(yearOfStudy)) {
        return 'Invalid year of study';
      }
    }

    if (location.trim().isEmpty) {
      return 'Location is required';
    }

    return null; // No validation errors
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'yearOfStudy': yearOfStudy,
      'location': location,
      'category': categoryToString(category),
      'attendanceCount': attendanceCount,
      'firstRegistered': firstRegistered.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'firestoreId': firestoreId,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'modifiedBy': modifiedBy,
      'modifiedAt': modifiedAt?.toIso8601String(),
      'isSynced': isSynced,
      'version': version,
    };
  }

  // JSON deserialization
  factory AttendeeModel.fromJson(Map<String, dynamic> json) {
    return AttendeeModel(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      yearOfStudy: json['yearOfStudy'] ?? '',
      location: json['location'],
      category: categoryFromString(json['category'] ?? 'student'),
      attendanceCount: json['attendanceCount'] ?? 0,
      firstRegistered: DateTime.parse(json['firstRegistered']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      firestoreId: json['firestoreId'],
      createdBy: json['createdBy'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      modifiedBy: json['modifiedBy'],
      modifiedAt: json['modifiedAt'] != null ? DateTime.parse(json['modifiedAt']) : null,
      isSynced: json['isSynced'] ?? false,
      version: json['version'] ?? 1,
    );
  }

  // Database serialization (for SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'year_of_study': yearOfStudy,
      'location': location,
      'category': categoryToString(category),
      'attendance_count': attendanceCount,
      'first_registered': firstRegistered.toIso8601String(),
      'last_updated': lastUpdated.toIso8601String(),
      'firestore_id': firestoreId,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'modified_by': modifiedBy,
      'modified_at': modifiedAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'version': version,
    };
  }

  // Database deserialization (from SQLite)
  factory AttendeeModel.fromMap(Map<String, dynamic> map) {
    return AttendeeModel(
      id: map['id'],
      name: map['name'],
      phoneNumber: map['phone_number'],
      yearOfStudy: map['year_of_study'] ?? '',
      location: map['location'],
      category: categoryFromString(map['category'] ?? 'student'),
      attendanceCount: map['attendance_count'] ?? 0,
      firstRegistered: DateTime.parse(map['first_registered']),
      lastUpdated: DateTime.parse(map['last_updated']),
      firestoreId: map['firestore_id'],
      createdBy: map['created_by'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      modifiedBy: map['modified_by'],
      modifiedAt: map['modified_at'] != null ? DateTime.parse(map['modified_at']) : null,
      isSynced: map['is_synced'] == 1,
      version: map['version'] ?? 1,
    );
  }

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'yearOfStudy': yearOfStudy,
      'location': location,
      'category': categoryToString(category),
      'attendanceCount': attendanceCount,
      'firstRegistered': firstRegistered.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'modifiedBy': modifiedBy,
      'modifiedAt': modifiedAt?.toIso8601String(),
      'version': version,
    };
  }

  // Firestore deserialization
  factory AttendeeModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return AttendeeModel(
      firestoreId: documentId,
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      yearOfStudy: data['yearOfStudy'] ?? '',
      location: data['location'] ?? '',
      category: categoryFromString(data['category'] ?? 'student'),
      attendanceCount: data['attendanceCount'] ?? 0,
      firstRegistered: data['firstRegistered'] != null
          ? DateTime.parse(data['firstRegistered'])
          : DateTime.now(),
      lastUpdated: data['lastUpdated'] != null
          ? DateTime.parse(data['lastUpdated'])
          : DateTime.now(),
      createdBy: data['createdBy'],
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : null,
      modifiedBy: data['modifiedBy'],
      modifiedAt: data['modifiedAt'] != null ? DateTime.parse(data['modifiedAt']) : null,
      isSynced: true, // Data from Firestore is considered synced
      version: data['version'] ?? 1,
    );
  }

  // Copy with method for updating fields
  AttendeeModel copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    String? yearOfStudy,
    String? location,
    AttendeeCategory? category,
    int? attendanceCount,
    DateTime? firstRegistered,
    DateTime? lastUpdated,
    String? firestoreId,
    String? createdBy,
    DateTime? createdAt,
    String? modifiedBy,
    DateTime? modifiedAt,
    bool? isSynced,
    int? version,
  }) {
    return AttendeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      yearOfStudy: yearOfStudy ?? this.yearOfStudy,
      location: location ?? this.location,
      category: category ?? this.category,
      attendanceCount: attendanceCount ?? this.attendanceCount,
      firstRegistered: firstRegistered ?? this.firstRegistered,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      firestoreId: firestoreId ?? this.firestoreId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isSynced: isSynced ?? this.isSynced,
      version: version ?? this.version,
    );
  }

  // Increment attendance count
  AttendeeModel incrementAttendance() {
    return copyWith(
      attendanceCount: attendanceCount + 1,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'AttendeeModel(id: $id, name: $name, phone: $phoneNumber, year: $yearOfStudy, location: $location, attendance: $attendanceCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendeeModel &&
        other.id == id &&
        other.name == name &&
        other.phoneNumber == phoneNumber &&
        other.yearOfStudy == yearOfStudy &&
        other.location == location &&
        other.category == category &&
        other.attendanceCount == attendanceCount &&
        other.firestoreId == firestoreId &&
        other.version == version;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, phoneNumber, yearOfStudy, location, category,
        attendanceCount, firestoreId, version);
  }
}
