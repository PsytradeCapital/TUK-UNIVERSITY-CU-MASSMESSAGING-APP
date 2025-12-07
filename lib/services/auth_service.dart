import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Service for handling Firebase Authentication
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current Firebase user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  /// Stream of authentication state changes
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  /// Sign up new user with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      // Create user document in Firestore
      if (userCredential.user != null) {
        final userModel = UserModel(
          uid: userCredential.user!.uid,
          email: email,
          name: name,
          role: UserRole.leader,  // Default role
          isApproved: false,      // Requires admin approval
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userModel.toFirestore());

        debugPrint('User created successfully: ${userCredential.user!.uid}');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign up error: ${e.code} - ${e.message}');
      throw AuthException(
        code: e.code,
        message: AuthException.getUserFriendlyMessage(e.code),
      );
    } catch (e) {
      debugPrint('Unexpected sign up error: $e');
      throw AuthException(
        code: 'unknown',
        message: 'An unexpected error occurred during sign up',
      );
    }
  }

  /// Sign in existing user with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login time
      if (userCredential.user != null) {
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'lastLoginAt': Timestamp.now(),
        });

        // Check if user is approved
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final isApproved = userData['isApproved'] as bool? ?? false;

          if (!isApproved) {
            // Sign out if not approved
            await signOut();
            throw AuthException(
              code: 'account-not-approved',
              message: AuthException.getUserFriendlyMessage('account-not-approved'),
            );
          }
        }

        debugPrint('User signed in successfully: ${userCredential.user!.uid}');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.code} - ${e.message}');
      throw AuthException(
        code: e.code,
        message: AuthException.getUserFriendlyMessage(e.code),
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('Unexpected sign in error: $e');
      throw AuthException(
        code: 'unknown',
        message: 'An unexpected error occurred during sign in',
      );
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Sign out error: $e');
      throw AuthException(
        code: 'sign-out-failed',
        message: 'Failed to sign out',
      );
    }
  }

  /// Reset password for email
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.code} - ${e.message}');
      throw AuthException(
        code: e.code,
        message: AuthException.getUserFriendlyMessage(e.code),
      );
    } catch (e) {
      debugPrint('Unexpected password reset error: $e');
      throw AuthException(
        code: 'unknown',
        message: 'Failed to send password reset email',
      );
    }
  }

  /// Update user profile (name and photo URL)
  Future<void> updateProfile({
    String? name,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException(
          code: 'no-user',
          message: 'No user is currently signed in',
        );
      }

      // Update Firebase Auth profile
      if (name != null) {
        await user.updateDisplayName(name);
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Update Firestore document
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      if (updates.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update(updates);
      }

      debugPrint('User profile updated successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('Profile update error: ${e.code} - ${e.message}');
      throw AuthException(
        code: e.code,
        message: 'Failed to update profile',
      );
    } catch (e) {
      debugPrint('Unexpected profile update error: $e');
      throw AuthException(
        code: 'unknown',
        message: 'Failed to update profile',
      );
    }
  }

  /// Get UserModel for current user from Firestore
  Future<UserModel?> getCurrentUserModel() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return null;

      return UserModel.fromFirestore(userDoc);
    } catch (e) {
      debugPrint('Error getting user model: $e');
      return null;
    }
  }

  /// Check if current user is approved
  Future<bool> isUserApproved() async {
    try {
      final userModel = await getCurrentUserModel();
      return userModel?.isApproved ?? false;
    } catch (e) {
      debugPrint('Error checking user approval: $e');
      return false;
    }
  }

  /// Check if current user is admin
  Future<bool> isUserAdmin() async {
    try {
      final userModel = await getCurrentUserModel();
      return userModel?.isAdmin ?? false;
    } catch (e) {
      debugPrint('Error checking user admin status: $e');
      return false;
    }
  }

  /// Reload current user data
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      debugPrint('Error reloading user: $e');
    }
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String code;
  final String message;

  AuthException({
    required this.code,
    required this.message,
  });

  /// Get user-friendly error message from Firebase error code
  static String getUserFriendlyMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address';
      case 'wrong-password':
        return 'Incorrect password. Please try again';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'invalid-email':
        return 'Invalid email address format';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'account-not-approved':
        return 'Your account is pending admin approval. Please contact an administrator';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'operation-not-allowed':
        return 'This operation is not allowed';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection';
      case 'no-user':
        return 'No user is currently signed in';
      case 'sign-out-failed':
        return 'Failed to sign out. Please try again';
      default:
        return 'Authentication error: $code';
    }
  }

  @override
  String toString() => 'AuthException: $message (code: $code)';
}
