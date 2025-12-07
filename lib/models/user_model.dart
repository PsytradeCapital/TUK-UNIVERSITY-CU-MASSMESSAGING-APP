import 'package:cloud_firestore/cloud_firestore.dart';

/// User roles in the system
enum UserRole {
  admin,   // Full access, can approve users and manage system
  leader,  // Can register attendees and send messages
  member,  // Read-only access to view data
}

/// User model for Firebase Authentication and Firestore
class UserModel {
  final String uid;              // Firebase UID
  final String email;
  final String name;
  final String? photoUrl;
  final UserRole role;
  final bool isApproved;         // Admin approval status
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
    this.role = UserRole.leader,  // Default role
    this.isApproved = false,      // Requires admin approval by default
    required this.createdAt,
    this.lastLoginAt,
  });

  /// Convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'role': _roleToString(role),
      'isApproved': isApproved,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  /// Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      uid: data['uid'] as String,
      email: data['email'] as String,
      name: data['name'] as String,
      photoUrl: data['photoUrl'] as String?,
      role: _stringToRole(data['role'] as String),
      isApproved: data['isApproved'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: data['lastLoginAt'] != null 
          ? (data['lastLoginAt'] as Timestamp).toDate() 
          : null,
    );
  }

  /// Create UserModel from Map (for testing or local storage)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      photoUrl: map['photoUrl'] as String?,
      role: _stringToRole(map['role'] as String),
      isApproved: map['isApproved'] as bool? ?? false,
      createdAt: map['createdAt'] is DateTime 
          ? map['createdAt'] as DateTime
          : (map['createdAt'] as Timestamp).toDate(),
      lastLoginAt: map['lastLoginAt'] != null
          ? (map['lastLoginAt'] is DateTime
              ? map['lastLoginAt'] as DateTime
              : (map['lastLoginAt'] as Timestamp).toDate())
          : null,
    );
  }

  /// Convert UserModel to Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'role': _roleToString(role),
      'isApproved': isApproved,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
    };
  }

  /// Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? photoUrl,
    UserRole? role,
    bool? isApproved,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  /// Convert UserRole enum to string
  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.leader:
        return 'leader';
      case UserRole.member:
        return 'member';
    }
  }

  /// Convert string to UserRole enum
  static UserRole _stringToRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'leader':
        return UserRole.leader;
      case 'member':
        return UserRole.member;
      default:
        return UserRole.member; // Default to member if unknown
    }
  }

  /// Get display name for role
  String getRoleDisplayName() {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.leader:
        return 'CU Leader';
      case UserRole.member:
        return 'Member';
    }
  }

  /// Check if user has admin privileges
  bool get isAdmin => role == UserRole.admin;

  /// Check if user can register attendees and send messages
  bool get canManageAttendees => isApproved && (role == UserRole.admin || role == UserRole.leader);

  /// Check if user can approve other users
  bool get canApproveUsers => isApproved && role == UserRole.admin;

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, name: $name, role: ${_roleToString(role)}, isApproved: $isApproved)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.name == name &&
        other.photoUrl == photoUrl &&
        other.role == role &&
        other.isApproved == isApproved;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        name.hashCode ^
        (photoUrl?.hashCode ?? 0) ^
        role.hashCode ^
        isApproved.hashCode;
  }
}

/// Exception thrown when user operations fail
class UserModelException implements Exception {
  final String message;
  
  UserModelException(this.message);
  
  @override
  String toString() => 'UserModelException: $message';
}
