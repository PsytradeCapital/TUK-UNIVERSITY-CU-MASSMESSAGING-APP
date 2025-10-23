class AttendeeModel {
  final int? id;
  final String name;
  final String phoneNumber;
  final String yearOfStudy;
  final String location;
  final int attendanceCount;
  final DateTime firstRegistered;
  final DateTime lastUpdated;

  AttendeeModel({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.yearOfStudy,
    required this.location,
    this.attendanceCount = 0,
    DateTime? firstRegistered,
    DateTime? lastUpdated,
  }) : firstRegistered = firstRegistered ?? DateTime.now(),
       lastUpdated = lastUpdated ?? DateTime.now();

  // Phone number validation for Kenyan formats
  static bool isValidKenyanPhone(String phone) {
    // Remove any whitespace
    phone = phone.replaceAll(RegExp(r'\s+'), '');
    
    // Check for +2547xxxxxxxx format (10 digits after +254)
    if (phone.startsWith('+254')) {
      String digits = phone.substring(4);
      return digits.length == 9 && 
             digits.startsWith('7') && 
             RegExp(r'^\d{9}$').hasMatch(digits);
    }
    
    // Check for 07xxxxxxxx format (10 digits starting with 07)
    if (phone.startsWith('07')) {
      return phone.length == 10 && RegExp(r'^07\d{8}$').hasMatch(phone);
    }
    
    // Check for 01xxxxxxxx format (10 digits starting with 01)
    if (phone.startsWith('01')) {
      return phone.length == 10 && RegExp(r'^01\d{8}$').hasMatch(phone);
    }
    
    return false;
  }

  // Normalize phone number to +254 format
  static String normalizePhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');
    
    if (phone.startsWith('07')) {
      return '+254${phone.substring(1)}';
    } else if (phone.startsWith('01')) {
      return '+254${phone.substring(1)}';
    } else if (phone.startsWith('+254')) {
      return phone;
    }
    
    return phone; // Return as-is if format not recognized
  }

  // Mask phone number for display (e.g., +254712****56)
  static String maskPhoneNumber(String phone) {
    if (phone.length < 4) return phone;
    
    if (phone.startsWith('+254') && phone.length >= 13) {
      return '${phone.substring(0, 7)}****${phone.substring(phone.length - 2)}';
    } else if (phone.startsWith('07') && phone.length >= 10) {
      return '${phone.substring(0, 4)}****${phone.substring(phone.length - 2)}';
    }
    
    // For other formats, mask middle digits
    if (phone.length >= 6) {
      return '${phone.substring(0, 3)}****${phone.substring(phone.length - 2)}';
    }
    
    return phone;
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
      return 'Invalid phone number format. Use +2547xxxxxxxx or 07xxxxxxxx';
    }
    
    if (yearOfStudy.isEmpty) {
      return 'Year of study is required';
    }
    
    List<String> validYears = ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year', '6th Year'];
    if (!validYears.contains(yearOfStudy)) {
      return 'Invalid year of study';
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
      'attendanceCount': attendanceCount,
      'firstRegistered': firstRegistered.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  // JSON deserialization
  factory AttendeeModel.fromJson(Map<String, dynamic> json) {
    return AttendeeModel(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      yearOfStudy: json['yearOfStudy'],
      location: json['location'],
      attendanceCount: json['attendanceCount'] ?? 0,
      firstRegistered: DateTime.parse(json['firstRegistered']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
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
      'attendance_count': attendanceCount,
      'first_registered': firstRegistered.toIso8601String(),
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  // Database deserialization (from SQLite)
  factory AttendeeModel.fromMap(Map<String, dynamic> map) {
    return AttendeeModel(
      id: map['id'],
      name: map['name'],
      phoneNumber: map['phone_number'],
      yearOfStudy: map['year_of_study'],
      location: map['location'],
      attendanceCount: map['attendance_count'] ?? 0,
      firstRegistered: DateTime.parse(map['first_registered']),
      lastUpdated: DateTime.parse(map['last_updated']),
    );
  }

  // Copy with method for updating fields
  AttendeeModel copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    String? yearOfStudy,
    String? location,
    int? attendanceCount,
    DateTime? firstRegistered,
    DateTime? lastUpdated,
  }) {
    return AttendeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      yearOfStudy: yearOfStudy ?? this.yearOfStudy,
      location: location ?? this.location,
      attendanceCount: attendanceCount ?? this.attendanceCount,
      firstRegistered: firstRegistered ?? this.firstRegistered,
      lastUpdated: lastUpdated ?? this.lastUpdated,
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
        other.attendanceCount == attendanceCount;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, phoneNumber, yearOfStudy, location, attendanceCount);
  }
}