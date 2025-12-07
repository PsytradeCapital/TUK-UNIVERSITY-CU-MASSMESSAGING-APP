import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Repository for managing user data in Firestore
class UserRepository {
  static final UserRepository _instance = UserRepository._internal();
  factory UserRepository() => _instance;
  UserRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'users';

  /// Create a new user in Firestore
  /// Returns the user ID
  Future<String> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(user.uid)
          .set(user.toFirestore());
      
      debugPrint('User created in Firestore: ${user.uid}');
      return user.uid;
    } catch (e) {
      debugPrint('Error creating user: $e');
      throw UserRepositoryException('Failed to create user: $e');
    }
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(uid)
          .get();

      if (!doc.exists) {
        debugPrint('User not found: $uid');
        return null;
      }

      return UserModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      throw UserRepositoryException('Failed to get user: $e');
    }
  }

  /// Update user data
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(user.uid)
          .update(user.toFirestore());
      
      debugPrint('User updated in Firestore: ${user.uid}');
    } catch (e) {
      debugPrint('Error updating user: $e');
      throw UserRepositoryException('Failed to update user: $e');
    }
  }

  /// Get all users
  Future<List<UserModel>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting all users: $e');
      throw UserRepositoryException('Failed to get all users: $e');
    }
  }

  /// Approve a user (set isApproved to true)
  Future<void> approveUser(String uid) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update({
        'isApproved': true,
      });
      
      debugPrint('User approved: $uid');
    } catch (e) {
      debugPrint('Error approving user: $e');
      throw UserRepositoryException('Failed to approve user: $e');
    }
  }

  /// Revoke user access (set isApproved to false)
  Future<void> revokeUserAccess(String uid) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update({
        'isApproved': false,
      });
      
      debugPrint('User access revoked: $uid');
    } catch (e) {
      debugPrint('Error revoking user access: $e');
      throw UserRepositoryException('Failed to revoke user access: $e');
    }
  }

  /// Update user role
  Future<void> updateUserRole(String uid, UserRole role) async {
    try {
      final roleString = _roleToString(role);
      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update({
        'role': roleString,
      });
      
      debugPrint('User role updated: $uid -> $roleString');
    } catch (e) {
      debugPrint('Error updating user role: $e');
      throw UserRepositoryException('Failed to update user role: $e');
    }
  }

  /// Get users by approval status
  Future<List<UserModel>> getUsersByApprovalStatus(bool isApproved) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('isApproved', isEqualTo: isApproved)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting users by approval status: $e');
      throw UserRepositoryException('Failed to get users by approval status: $e');
    }
  }

  /// Get users by role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    try {
      final roleString = _roleToString(role);
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('role', isEqualTo: roleString)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting users by role: $e');
      throw UserRepositoryException('Failed to get users by role: $e');
    }
  }

  /// Convert UserRole enum to string
  String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.leader:
        return 'leader';
      case UserRole.member:
        return 'member';
    }
  }

  /// Search users by name or email
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final allUsers = await getAllUsers();
      
      // Filter users by name or email containing the query (case-insensitive)
      final filteredUsers = allUsers.where((user) {
        final lowerQuery = query.toLowerCase();
        return user.name.toLowerCase().contains(lowerQuery) ||
               user.email.toLowerCase().contains(lowerQuery);
      }).toList();

      return filteredUsers;
    } catch (e) {
      debugPrint('Error searching users: $e');
      throw UserRepositoryException('Failed to search users: $e');
    }
  }

  /// Stream of all users (real-time updates)
  Stream<List<UserModel>> usersStream() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  /// Stream of users by approval status (real-time updates)
  Stream<List<UserModel>> usersByApprovalStatusStream(bool isApproved) {
    return _firestore
        .collection(_collectionName)
        .where('isApproved', isEqualTo: isApproved)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  /// Delete user (use with caution)
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .delete();
      
      debugPrint('User deleted from Firestore: $uid');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      throw UserRepositoryException('Failed to delete user: $e');
    }
  }
}

/// Exception thrown when user repository operations fail
class UserRepositoryException implements Exception {
  final String message;
  
  UserRepositoryException(this.message);
  
  @override
  String toString() => 'UserRepositoryException: $message';
}
